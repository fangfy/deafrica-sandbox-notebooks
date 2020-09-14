
####
# functions to calculate BRDF normalization fractor for a S2 image
#
#
# To do: output a interpolate function that can be interpolated into any coordinates
#

# +
# import packages

import boto3
from botocore import UNSIGNED
from botocore.client import Config
import requests
import json
from bs4 import BeautifulSoup as bs

import numpy as np
from scipy import interpolate
import xarray as xr

from matplotlib import pyplot as plt


# +
# get angles from metadata

def get_xml(ds):
    stac_json = ds.uris[0]
    if stac_json.startswith('s3'):
        bucket = stac_json.split('//')[1].split('/')[0]
        key = stac_json.split(bucket+'/')[1]
    else:
        address = stac_json.split('//')[1].split('/')[0]
        bucket = address.split('.')[0]
        key = stac_json.split(address+'/')[1]
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    response = s3.get_object(Bucket = bucket, Key = key)
    jsonObject = json.loads(response['Body'].read())
    return jsonObject['assets']['metadata']['href']


def parse_xml(metadataurl):
    response = requests.get(metadataurl)
    parsed = bs(response.content, "lxml")
    return parsed


def parse_values(angles_list):
    rows = [np.array(row.contents[0].split()).astype(float) for row in angles_list.find_all('values')]
    return np.vstack(rows)


def parse_and_fill(list_of_angles, mean_overlap=True):
    angles = parse_values(list_of_angles[0].values_list)
    
    for z in list_of_angles[1:]:
        det_angles = parse_values(z.values_list)
        empty = np.isnan(angles)
        angles[empty] = det_angles[empty]
        if mean_overlap:
            new_empty = np.isnan(det_angles)
            det_angles[new_empty] = angles[new_empty]
            angles = (angles+det_angles)/2

    return angles


# +
# for each band, interpolate solar and viewing angles 

def s2_band_name_to_id(band_name):
    return {'B01':0, 'B02':1, 'B03':2, 'B04':3, 'B05':4, 'B06':5, 'B07':6, 'B08':7, 'B8A':8,
            'B09':9, 'B11':10, 'B12':11}[band_name]


def s2_band_name_to_res(band_name):
    return {'B01':20, 'B02':10, 'B03':10, 'B04':10, 'B05':20, 'B06':20, 'B07':20, 'B08':10, 'B8A':20,
            'B09':60, 'B11':20, 'B12':20}[band_name]


def get_image_size(parsed, res):
    size = [s for s in parsed.find_all('size') if int(s.attrs['resolution'])==res][0]
    return int(size.nrows.contents[0]), int(size.ncols.contents[0])


def get_geo_coordinates(parsed, res, nrows=None, ncols=None, row_step=None, col_step=None):
    geo = [s for s in parsed.find_all('geoposition') if int(s.attrs['resolution'])==res][0]
    ulx, uly = int(geo.ulx.contents[0]), int(geo.uly.contents[0])
    xdim, ydim = int(geo.xdim.contents[0]), int(geo.ydim.contents[0])
    if nrows is None or ncols is None:
        nrows, ncols = get_image_size(parsed, res)
    if row_step is None or col_step is None:
        return {'x': ulx+np.arange(ncols)*xdim, 'y': uly+np.arange(nrows)*ydim}
    else:
        return {'x': ulx+np.arange(ncols)*np.sign(xdim)*col_step, 'y': uly+np.arange(nrows)*np.sign(ydim)*row_step}

def fill_nan(row):
    # extraplate a partial row
    valid = ~np.isnan(row)
    if valid.all(): return row
    output_x = np.arange(len(row))
    input_x = output_x[valid]
    f = interpolate.interp1d(input_x, row[valid], fill_value='extrapolate')
    return f(output_x)


def fill_nan_2d(table_raw):
    # extrapolate (nearest neighbor) a partial image
    valid = ~np.isnan(table_raw)
    output_y = np.arange(table_raw.shape[0])
    output_x = np.arange(table_raw.shape[1])
    input_x, input_y= np.meshgrid(output_y, output_x)
    f = interpolate.interp2d(input_x[valid], input_y[valid], table_raw[valid], kind='linear')
    return f(output_x, output_y)


def interpolate_table(table, row_step, col_step, res, nrows, ncols, **kw):
    # input can't have nan 
    y = np.arange(table.shape[0])*row_step/res
    x = np.arange(table.shape[1])*col_step/res
    rbs = interpolate.RectBivariateSpline(x, y, table, **kw)
    return rbs(np.arange(nrows), np.arange(ncols))


def fill_and_interpolate_table(table_raw, row_step, col_step, res, nrows, ncols):
    # doesn't seem to interploate well for sparse input grid
    valid = ~np.isnan(table_raw)
    x, y = np.meshgrid(np.arange(table_raw.shape[0])*row_step/res, np.arange(table_raw.shape[1])*col_step/res)
    f = interpolate.interp2d(x[valid], y[valid], table_raw[valid], kind='linear')
    return f(np.arange(nrows), np.arange(ncols))


def get_angles(parsed, band_name, angletype='zenith', mean_overlap=False, interpolate=False, **kw):
    
    band_id = s2_band_name_to_id(band_name)
    res = s2_band_name_to_res(band_name)
    nrows, ncols = get_image_size(parsed, res)
    
    angles = parsed.tile_angles.find_all(angletype)
    # separate solar and satellite
    solar_angles = [z for z in angles if 'sun' in z.parent.name][0]
    satellite_angles = [z for z in angles if 'viewing' in z.parent.name]

    if interpolate:
        coords = get_geo_coordinates(parsed, res, nrows, ncols)
        solar_za = interpolate_table(parse_values(solar_angles),
                                 int(solar_angles.row_step.contents[0]), int(solar_angles.col_step.contents[0]),
                                 res, nrows, ncols, **kw)
        # satellite angles are provided for each detector
        table_raw = parse_and_fill(satellite_angles, mean_overlap=mean_overlap)
        table = fill_nan_2d(table_raw)
        satellite_za = interpolate_table(table,
                                 int(satellite_angles[0].row_step.contents[0]), int(satellite_angles[0].col_step.contents[0]),
                                 res, nrows, ncols)
    else:
        solar_za = parse_values(solar_angles)
        satellite_za = parse_and_fill(satellite_angles, mean_overlap=mean_overlap)
        coords = get_geo_coordinates(parsed, res, solar_za.shape[0], solar_za.shape[1], int(solar_angles.row_step.contents[0]), int(solar_angles.col_step.contents[0]))
        
    return xr.DataArray(solar_za, coords=coords, dims=['y', 'x'], name=f'solar_{angletype}'), xr.DataArray(satellite_za, coords=coords, dims=['y', 'x'], name=f'view_{angletype}')

# +
# calculate the brdf factor

def k_geom(solar_za, view_za, relative_az):
    """
    kernel function for geometric scattering component

    Input angles should be in radians
    solar_za: solar zenith angle
    view_za: satellite viewing zenith angle
    relative_az: relative azimuth angle between the sun and viewing directions
    """
    return ((np.pi-relative_az) * np.cos(relative_az) + np.sin(relative_az)) * np.tan(solar_za) * np.tan(view_za)/2./np.pi \
            - (np.tan(solar_za) + np.tan(view_za) + np.sqrt(np.tan(solar_za)**2 + np.tan(view_za)**2 - 2.*np.tan(solar_za)*np.tan(view_za)*np.cos(relative_az)))/np.pi


def k_vol(solar_za, view_za, relative_az):
    """
    kernel function for volume scattering component.

    Input angles should be in radians
    solar_za: solar zenith angle
    view_za: satellite viewing zenith angle
    relative_az: relative azimuth angle between the sun and viewing directions
    """
    cos_scattering = np.cos(solar_za) * np.cos(view_za) + np.sin(solar_za) * np.sin(view_za) * np.cos(relative_az)
    sin_scattering = np.sqrt(1. - cos_scattering**2)
    return 4.*((np.pi/2 - np.arccos(cos_scattering)) * cos_scattering + sin_scattering)/(np.cos(solar_za) + np.cos(view_za))/3./np.pi - 1./3.


def check_kgeom():
    """
    function to test implementation of geometric scattering compoent
    for comparison to figure 2 in http://web.gps.caltech.edu/~vijay/Papers/BRDF/roujean-etal-92.pdf
    """
    view = np.arange(-80, 80, 1)
    for sun in [0, 30, 60]:
        # backward 
        b = k_geom(sun*np.pi/180., np.abs(view[view<0])*np.pi/180., 0)
        # forward
        f = k_geom(sun*np.pi/180., view[view>=0]*np.pi/180., np.pi)  
        plt.plot(view, np.hstack([b,f]), label=f'sun zenith {sun}');
    plt.legend();

    
def check_kvol():
    """
    function to test implementation of volume scattering compoent
    for comparison to figure 2 in http://web.gps.caltech.edu/~vijay/Papers/BRDF/roujean-etal-92.pdf
    """
    view = np.arange(-80, 80, 1)
    for sun in [0, 30, 60]:
        # backward 
        b = k_vol(sun*np.pi/180., np.abs(view[view<0])*np.pi/180., 0)
        # forward
        f = k_vol(sun*np.pi/180., view[view>=0]*np.pi/180., np.pi)
        plt.plot(view, np.hstack([b,f]), label=f'sun zenith {sun}');
    plt.legend();


def relative_angle(solar_az, view_az):
    rel = np.abs(solar_az-view_az)
    if type(rel) is xr.DataArray:
        rel = rel.where(rel<=180, 360-rel)
    else:
        rel[rel>180] = 360 - rel[rel>180]
    return rel*np.pi/180.



# +
# get BRDF parameters

def s2_band_brdf_roy2017(band_name):
    """
    returns fiso, fgeo, fvol
    """
    return {'B02':(0.0774, 0.0079, 0.0372), 
            'B03':(0.1306, 0.0178, 0.0580), 
            'B04':(0.1690, 0.0227, 0.0574),  
            'B08':(0.3093, 0.0330, 0.1535),  
            'B11':(0.3430, 0.0453, 0.1154),  
            'B12':(0.2658, 0.0387, 0.0639), }[band_name]


def s2_band_brdf_flood2020(band_name, ):
    """
    returns 1, f'geo, f'vol
    """
    return {'B02':(1, 0.3087, 0.3399), 
            'B03':(1, 0.1970, 0.6527), 
            'B04':(1, 0.1564, 0.4404),
            'B05':(1, 0.1455, 0.5411),
            'B06':(1, 0.1083, 0.6793),
            'B07':(1, 0.1078, 0.6705),
            'B08':(1, 0.0868, 0.8015),
            'B8A':(1, 0.1094, 0.6251),
            'B11':(1, 0.1500, 0.3216),  
            'B12':(1, 0.1753, 0.2466), }[band_name]



# +
# calculate normlized BRDF correction for nadir view and sun angle of 45 

def normalized_brdf(parsed, band_name, method = 'flood'):
    
    if method == 'flood':
        fiso, fgeo, fvol = s2_band_brdf_flood2020(band_name)
    else:
        fiso, fgeo, fvol = s2_band_brdf_roy2017(band_name)
        
    solar_za, satellite_za = get_angles(parsed, band_name, 'zenith')
    solar_az, satellite_az = get_angles(parsed, band_name, 'azimuth')
    
    # convert angles to radian
    solar_za, satellite_za = solar_za*np.pi/180., satellite_za*np.pi/180.
    # calculate relative azimuth
    relative_az = relative_angle(solar_az, satellite_az)
    # geometric kernel
    f_geom = k_geom(solar_za, satellite_za, relative_az)
    # volume scattering kernel
    f_vol = k_vol(solar_za, satellite_za, relative_az)
    
    # normalization factor
    brdf_45 = fiso + fgeo*k_geom(np.pi/4., 0., 0.) + fvol*k_vol(np.pi/4., 0., 0.)
    # calcuate brdf
    return (fiso + fgeo*f_geom + fvol*f_vol)/brdf_45

