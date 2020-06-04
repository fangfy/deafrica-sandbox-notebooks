#!/usr/bin/env python

import os
import xarray as xr
import numpy as np

from hdstats import nangeomedian_pcm as gm
import dask
from dask.diagnostics import ProgressBar

import sys
sys.path.append("../Scripts")
from deafrica_datahandling import load_ard

import datacube
from datacube.utils import geometry

from skimage.morphology import binary_dilation, disk

def reshape_for_geomedian(ds, axis='time'):
    dims = set(v.dims for v in ds.data_vars.values())
    if len(dims) != 1:
        raise ValueError("All bands should have same dimensions")

    dims = dims.pop()
    if len(dims) != 3:
        raise ValueError("Expect 3 dimensions on input")

    if axis not in dims:
        raise ValueError(f"No such axis: {axis}")

    dims = tuple(d for d in dims if d != axis) + ('band', axis)

    nodata = set(getattr(v, 'nodata', None) for v in ds.data_vars.values())
    if len(nodata) == 1:
        nodata = nodata.pop()
    else:
        nodata = None

    # xx: {y, x}, band, time
    xx = ds.to_array(dim='band').transpose(*dims)

    if nodata is not None:
        xx.attrs.update(nodata=nodata)

    return xx


def xr_geomedian(ds, axis='time', where=None, **kwargs):
    """

    :param ds: xr.Dataset|xr.DataArray|numpy array

    Other parameters:
    **kwargs -- passed on to pcm.gnmpcm
       maxiters   : int         1000
       eps        : float       0.0001
       num_threads: int| None   None
    """

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

        data = dask.array.map_blocks(lambda x: gm(x, **kwargs),
                             xx_data,
                             name='geomedian',
                             dtype=xx_data.dtype,
                             drop_axis=3)
    else:
        data = gm(xx_data, **kwargs)

    if set_nan is not None:
        data[set_nan, :] = np.nan

    if xx is None:
        return data

    dims = xx.dims[:-1]
    cc = {k: xx.coords[k] for k in dims}
    xx_out = xr.DataArray(data, dims=dims, coords=cc)

    if ds is None:
    #    xx_out.attrs.update(xx.attrs)
        return xx_out

    ds_out = xx_out.to_dataset(dim='band')
    for b in ds.data_vars.keys():
        src, dst = ds[b], ds_out[b]
        #dst.attrs.update(src.attrs)

    return ds_out



def run_tile(x, y, time, output_filename, cloud_labels=[3,8,9,10], cloud_buffer=20, bad_labels=[0,1],
             crs="EPSG:6933", output_crs="EPSG:6933", resolution=(-20,20),
             products= ["s2_l2a"],
             dask_chunk = {'time': -1, 'x':2000, 'y': 2000},
             outputdir = 's2_geomedian', 
             bands=['blue','green','red','red_edge_1','red_edge_2','red_edge_3','nir_2','swir_1','swir_2'], 
             redo = False):
    if not os.path.exists(outputdir): os.mkdir(outputdir)
    outpath = os.path.join(outputdir,output_filename) #'s2_%s_%s_%s.nc'%(time[0], time[1], tilename.replace(',','_')))
    if os.path.exists(outpath):
        if not redo: return
        else: os.system('rm %s'%outpath)
    
    dc = datacube.Datacube()
    datasets = []
    for product in products:
        data = dc.load(product = product, measurements = bands + ["SCL"], 
                       crs=crs,
                       output_crs=output_crs,
                       resolution=resolution, 
                       group_by="solar_day",
                       dask_chunks=dask_chunk,
                       x = x, y = y, time = time)

        if not bands[0] in data:
            continue
        
        cloud = data['SCL'].isin(cloud_labels)
        cloud = cloud.groupby('time').apply(binary_dilation, selem=disk(cloud_buffer))
        bad = data['SCL'].isin(bad_labels)
        for band in bands:
            data[band]= data[band].where(~cloud).where(~bad).astype('float32')
        
        datasets.append(data[bands].dropna(how='all', dim='time'))
   
    if len(datasets)== 0: return
    
    data = xr.concat(datasets, dim='time').chunk(dask_chunk)
     
    if len(bands)==1:
        arr = data[bands[0]]
        ref = xr.apply_ufunc(np.nanmedian, arr, kwargs = {'axis':-1},
                             input_core_dims=[['time']], dask='parallelized', output_dtypes=[np.float32])
    else:
        ref = xr_geomedian(data[bands])
   
    with ProgressBar(dt=10):
        ref = ref.compute()

    ref.attrs['crs'] = geometry.CRS(output_crs).wkt
    ref.to_netcdf(outpath)
    return ref

    #if (~np.isnan(ref[bands[0]])).sum().values==0: 
    #    print("Empty tile",tilename)
    #    return

    
if __name__=='__main__':
    #run_tile((-200000.0, -100000.0), (800000.0, 900000.0), "-2,8", year = '2019')
    x, y = (-190000.0, -180000.0), (880000.0, 890000.0)
    ref = run_tile(x, y, ("2019-06-01", "2019-12-31"), "test.nc", bands=['blue','green','red'], redo=True, dask_chunk={})




