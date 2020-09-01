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


def run_tile(x, y, time, output_filename, cloud_labels=[3,8,9,10], cloud_buffer=0, bad_labels=[0,1],
             crs="EPSG:6933", output_crs="EPSG:6933", resolution=(-20,20),
             dask_chunks = {'time': -1, 'x':2000, 'y': 2000},
             cloud_cover = [0, 100],
             bands=['blue','green','red','red_edge_1','red_edge_2','red_edge_3','nir_1', 'nir_2','swir_1','swir_2'], 
             redo = False, **kwargs):
    
    outputdir = os.path.dirname(output_filename)
    if not os.path.exists(outputdir): os.mkdir(outputdir)
    
    if os.path.exists(output_filename):
        if not redo: return
        else: os.system('rm %s'%output_filename)
    
    dc = datacube.Datacube()
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
    if cloud_buffer>0: cloud = cloud.groupby('time').apply(binary_dilation, selem=disk(cloud_buffer))
    bad = data['SCL'].isin(bad_labels)
    for band in bands:
        data[band]= data[band].where(~cloud).where(~bad).astype('float32')
        
    data = data[bands].dropna(how='all', dim='time')
    
    print("%d images during %s - %s"%(len(data.time), time[0], time[1]))
    
    if len(bands)==1:
        arr = data[bands[0]]
        ref = xr.apply_ufunc(np.nanmedian, arr, kwargs = {'axis':-1},
                             input_core_dims=[['time']], dask='parallelized', output_dtypes=[np.float32])
    else:
        ref = xr_geomedian(data[bands])
   
    if dask_chunks: ref= ref.compute()
    ref.attrs['crs'] = geometry.CRS(output_crs).wkt
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




