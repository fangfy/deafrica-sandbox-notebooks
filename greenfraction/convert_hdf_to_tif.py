
import os, glob
import gdal

files = glob.glob('MODIS_Senegal/*.hdf')
for f in files:
    g = gdal.Open(f, gdal.GA_ReadOnly)
    dest_src = [(f.replace(".hdf", f"_{d[0].split(':')[-1]}.tif"), d[0]) for d in g.GetSubDatasets()]
    for dest, src in dest_src:
        if not os.path.exists(dest): t=gdal.Translate(dest, src)

        