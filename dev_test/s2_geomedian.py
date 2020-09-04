#!/usr/bin/env python

import os
import xarray as xr
import numpy as np

from odc.algo import xr_geomedian
from dask.diagnostics import ProgressBar

import sys
sys.path.append("../Scripts")
from deafrica_datahandling import load_ard

import datacube
from datacube.utils import geometry

from skimage.morphology import binary_dilation, disk

import dask
import dask.array as da
from odc.algo import randomize, reshape_for_geomedian
from datacube.utils.geometry import assign_crs

def xr_geomedian_tmad(ds, axis='time', where=None, **kw):
    """
    :param ds: xr.Dataset|xr.DataArray|numpy array
    Other parameters:
    **kwargs -- passed on to pcm.gnmpcm
       maxiters   : int         1000
       eps        : float       0.0001
       num_threads: int| None   None
    """

    import hdstats
    def gm_tmad(arr, **kw):
        """
        arr: a high dimensional numpy array where the last dimension will be reduced. 
    
        returns: a numpy array with one less dimension than input.
        """
        gm = hdstats.nangeomedian_pcm(arr, **kw)
        nt = kw.pop('num_threads', None)
        nocheck = kw.pop('nocheck', False)
        emad = hdstats.emad_pcm(arr, gm, num_threads=nt, nocheck=nocheck)[:,:, np.newaxis]
        smad = hdstats.smad_pcm(arr, gm, num_threads=nt, nocheck=nocheck)[:,:, np.newaxis]
        bcmad = hdstats.bcmad_pcm(arr, gm, num_threads=nt, nocheck=nocheck)[:,:, np.newaxis]
        return np.concatenate([gm, emad, smad, bcmad], axis=-1)


    def norm_input(ds, axis):
        if isinstance(ds, xr.DataArray):
            xx = ds
            if len(xx.dims) != 4:
                raise ValueError("Expect 4 dimensions on input: y,x,band,time")
            if axis is not None and xx.dims[3] != axis:
                raise ValueError(f"Can only reduce last dimension, expect: y,x,band,{axis}")
            return None, xx, xx.data
        elif isinstance(ds, xr.Dataset):
            xx = reshape_for_geomedian(ds, axis)
            return ds, xx, xx.data
        else:  # assume numpy or similar
            xx_data = ds
            if xx_data.ndim != 4:
                raise ValueError("Expect 4 dimensions on input: y,x,band,time")
            return None, None, xx_data

    kw.setdefault('nocheck', False)
    kw.setdefault('num_threads', 1)
    kw.setdefault('eps', 1e-6)

    ds, xx, xx_data = norm_input(ds, axis)
    is_dask = dask.is_dask_collection(xx_data)

    if where is not None:
        if is_dask:
            raise NotImplementedError("Dask version doesn't support output masking currently")

        if where.shape != xx_data.shape[:2]:
            raise ValueError("Shape for `where` parameter doesn't match")
        set_nan = ~where
    else:
        set_nan = None

    if is_dask:
        if xx_data.shape[-2:] != xx_data.chunksize[-2:]:
            xx_data = xx_data.rechunk(xx_data.chunksize[:2] + (-1, -1))

        data = da.map_blocks(lambda x: gm_tmad(x, **kw),
                             xx_data,
                             name=randomize('geomedian'),
                             dtype=xx_data.dtype, 
                             chunks=xx_data.chunks[:-2] + (xx_data.chunks[-2][0]+3,),
                             drop_axis=3)
    else:
        data = gm_tmad(xx_data, **kw)

    if set_nan is not None:
        data[set_nan, :] = np.nan

    if xx is None:
        return data

    dims = xx.dims[:-1]
    cc = {k: xx.coords[k] for k in dims}
    cc[dims[-1]] = np.hstack([xx.coords[dims[-1]].values,['emad', 'smad', 'bcmad']])
    xx_out = xr.DataArray(data, dims=dims, coords=cc)

    if ds is None:
        xx_out.attrs.update(xx.attrs)
        return xx_out

    ds_out = xx_out.to_dataset(dim='band')
    for b in ds.data_vars.keys():
        src, dst = ds[b], ds_out[b]
        dst.attrs.update(src.attrs)

    return assign_crs(ds_out, crs=ds.geobox.crs)


def run_tile(x, y, time, output_filename, cloud_labels=[3,8,9,10], cloud_buffer=0, bad_labels=[0,1],
             crs="EPSG:6933", output_crs="EPSG:6933", resolution=(-20,20),
             dask_chunks = {'time': -1, 'x':2000, 'y': 2000},
             cloud_cover = [0, 100],
             bands=['blue','green','red','red_edge_1','red_edge_2','red_edge_3','nir_1', 'nir_2','swir_1','swir_2'], 
             redo = False,
             tmad = False,
             **kwargs):
    
    outputdir = os.path.dirname(output_filename)
    if not os.path.exists(outputdir): os.mkdir(outputdir)
    
    if os.path.exists(output_filename):
        if not redo: return
        else: os.system('rm %s'%output_filename)
    
    dc = datacube.Datacube()
    
    if cloud_buffer>0:
        data = dc.load(product = "s2_l2a", measurements = bands + ["SCL"], 
                   crs=crs,
                   output_crs=output_crs,
                   resolution=resolution, 
                   group_by="solar_day",
                   dask_chunks=dask_chunks,
                   x = x, y = y, time = time,
                   cloud_cover=cloud_cover,
                   **kwargs)

        if not bands[0] in data:
            print("No data found")
            return
    
        cloud = data['SCL'].isin(cloud_labels)
        cloud = cloud.groupby('time').apply(binary_dilation, selem=disk(cloud_buffer))
        bad = data['SCL'].isin(bad_labels)
        for band in bands:
            data[band]= data[band].where(~cloud).where(~bad).astype('float32')
        data = data[bands].dropna(how='all', dim='time')
        if tmad:
            data=data/10000.
    else:
        if tmad: 
            scaling='normalised'
        else:
            scaling='raw'
        data = load_ard(dc, products = ["s2_l2a"], 
                        measurements = bands,
                       crs=crs,
                       output_crs=output_crs,
                       resolution=resolution, 
                       group_by="solar_day",
                       dask_chunks=dask_chunks,
                       x = x, y = y, time = time,
                       cloud_cover=cloud_cover,
                        scaling = scaling,
                       **kwargs)
    
    print("%d images during %s - %s"%(len(data.time), time[0], time[1]))
    
    if len(bands)==1:
        arr = data[bands[0]]
        ref = xr.apply_ufunc(np.nanmedian, arr, kwargs = {'axis':-1},
                             input_core_dims=[['time']], dask='parallelized', output_dtypes=[np.float32])
    else:
        if tmad:
            ref = xr_geomedian_tmad(data[bands])
        else:
            ref = xr_geomedian(data[bands])
   
    if dask_chunks: ref= ref.compute()
    ref.attrs['nobs'] = len(data.time)
    ref.attrs['cloud_cover'] = f'{cloud_cover[0]}-{cloud_cover[1]}'
    #with ProgressBar(dt=10):
    ref.to_netcdf(output_filename)
    return ref

    #if (~np.isnan(ref[bands[0]])).sum().values==0: 
    #    print("Empty tile",tilename)
    #    return

    
    
if __name__=='__main__':
    #run_tile((-200000.0, -100000.0), (800000.0, 900000.0), "-2,8", year = '2019')
    x, y = (-190000.0, -180000.0), (880000.0, 890000.0)
    ref = run_tile(x, y, ("2020-01-01", "2020-03-31"), "test.nc", bands=['blue','green','red'], redo=True, dask_chunks={})




