#!/bin/sh

GREP_OPTIONS=''

cookiejar=$(mktemp cookies.XXXXXXXXXX)
netrc=$(mktemp netrc.XXXXXXXXXX)
chmod 0600 "$cookiejar" "$netrc"
function finish {
  rm -rf "$cookiejar" "$netrc"
}

trap finish EXIT
WGETRC="$wgetrc"

prompt_credentials() {
    echo "Enter your Earthdata Login or other provider supplied credentials"
    read -p "Username (fangfy): " username
    username=${username:-fangfy}
    read -s -p "Password: " password
    echo "machine urs.earthdata.nasa.gov login $username password $password" >> $netrc
    echo
}

exit_with_error() {
    echo
    echo "Unable to Retrieve Data"
    echo
    echo $1
    echo
    echo "https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.31/MCD15A3H.A2017365.h16v07.006.2018005032347.hdf"
    echo
    exit 1
}

prompt_credentials
  detect_app_approval() {
    approved=`curl -s -b "$cookiejar" -c "$cookiejar" -L --max-redirs 2 --netrc-file "$netrc" https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.31/MCD15A3H.A2017365.h16v07.006.2018005032347.hdf -w %{http_code} | tail  -1`
    if [ "$approved" -ne "302" ]; then
        # User didn't approve the app. Direct users to approve the app in URS
        exit_with_error "Please ensure that you have authorized the remote application by visiting the link below "
    fi
}

setup_auth_curl() {
    # Firstly, check if it require URS authentication
    status=$(curl -s -z "$(date)" -w %{http_code} https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.31/MCD15A3H.A2017365.h16v07.006.2018005032347.hdf | tail -1)
    if [[ "$status" -ne "200" && "$status" -ne "304" ]]; then
        # URS authentication is required. Now further check if the application/remote service is approved.
        detect_app_approval
    fi
}

setup_auth_wget() {
    # The safest way to auth via curl is netrc. Note: there's no checking or feedback
    # if login is unsuccessful
    touch ~/.netrc
    chmod 0600 ~/.netrc
    credentials=$(grep 'machine urs.earthdata.nasa.gov' ~/.netrc)
    if [ -z "$credentials" ]; then
        cat "$netrc" >> ~/.netrc
    fi
}

fetch_urls() {
  if command -v curl >/dev/null 2>&1; then
      setup_auth_curl
      while read -r line; do
        # Get everything after the last '/'
        filename="${line##*/}"

        # Strip everything after '?'
        stripped_query_params="${filename%%\?*}"

        curl -f -b "$cookiejar" -c "$cookiejar" -L --netrc-file "$netrc" -g -o $stripped_query_params -- $line && echo || exit_with_error "Command failed with error. Please retrieve the data manually."
      done;
  elif command -v wget >/dev/null 2>&1; then
      # We can't use wget to poke provider server to get info whether or not URS was integrated without download at least one of the files.
      echo
      echo "WARNING: Can't find curl, use wget instead."
      echo "WARNING: Script may not correctly identify Earthdata Login integrations."
      echo
      setup_auth_wget
      while read -r line; do
        # Get everything after the last '/'
        filename="${line##*/}"

        # Strip everything after '?'
        stripped_query_params="${filename%%\?*}"

        wget --load-cookies "$cookiejar" --save-cookies "$cookiejar" --output-document $stripped_query_params --keep-session-cookies -- $line && echo || exit_with_error "Command failed with error. Please retrieve the data manually."
      done;
  else
      exit_with_error "Error: Could not find a command-line downloader.  Please install curl or wget"
  fi
}

fetch_urls <<'EDSCEOF'
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.31/MCD15A3H.A2017365.h16v07.006.2018005032347.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.27/MCD15A3H.A2017361.h16v07.006.2018002204426.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.23/MCD15A3H.A2017357.h16v07.006.2018002133744.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.19/MCD15A3H.A2017353.h16v07.006.2017361223011.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.15/MCD15A3H.A2017349.h16v07.006.2017354030310.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.11/MCD15A3H.A2017345.h16v07.006.2017353214209.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.07/MCD15A3H.A2017341.h16v07.006.2017346032306.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.03/MCD15A3H.A2017337.h16v07.006.2017342030052.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.29/MCD15A3H.A2017333.h16v07.006.2017341183221.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.25/MCD15A3H.A2017329.h16v07.006.2017334154342.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.21/MCD15A3H.A2017325.h16v07.006.2017333161005.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.17/MCD15A3H.A2017321.h16v07.006.2017331211541.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.13/MCD15A3H.A2017317.h16v07.006.2017331160710.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.09/MCD15A3H.A2017313.h16v07.006.2017325161821.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.05/MCD15A3H.A2017309.h16v07.006.2017314040534.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.01/MCD15A3H.A2017305.h16v07.006.2017312184359.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.28/MCD15A3H.A2017301.h16v07.006.2017310191337.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.24/MCD15A3H.A2017297.h16v07.006.2017303194714.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.20/MCD15A3H.A2017293.h16v07.006.2017300140734.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.16/MCD15A3H.A2017289.h16v07.006.2017297185112.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.12/MCD15A3H.A2017285.h16v07.006.2017290125918.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.08/MCD15A3H.A2017281.h16v07.006.2017286040534.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.04/MCD15A3H.A2017277.h16v07.006.2017283110802.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.30/MCD15A3H.A2017273.h16v07.006.2017278030914.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.26/MCD15A3H.A2017269.h16v07.006.2017276172423.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.22/MCD15A3H.A2017265.h16v07.006.2017271135321.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.18/MCD15A3H.A2017261.h16v07.006.2017266035620.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.14/MCD15A3H.A2017257.h16v07.006.2017262125148.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.10/MCD15A3H.A2017253.h16v07.006.2017258030624.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.06/MCD15A3H.A2017249.h16v07.006.2017254031140.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.02/MCD15A3H.A2017245.h16v07.006.2017250143536.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.29/MCD15A3H.A2017241.h16v07.006.2017249173822.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.25/MCD15A3H.A2017237.h16v07.006.2017242030216.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.21/MCD15A3H.A2017233.h16v07.006.2017248101410.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.17/MCD15A3H.A2017229.h16v07.006.2017234150145.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.13/MCD15A3H.A2017225.h16v07.006.2017230032243.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.09/MCD15A3H.A2017221.h16v07.006.2017227171555.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.05/MCD15A3H.A2017217.h16v07.006.2017227125026.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.01/MCD15A3H.A2017213.h16v07.006.2017227125012.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.28/MCD15A3H.A2017209.h16v07.006.2017214184630.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.24/MCD15A3H.A2017205.h16v07.006.2017212195622.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.20/MCD15A3H.A2017201.h16v07.006.2017212170613.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.16/MCD15A3H.A2017197.h16v07.006.2017202031826.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.12/MCD15A3H.A2017193.h16v07.006.2017198204015.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.08/MCD15A3H.A2017189.h16v07.006.2017194104641.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.04/MCD15A3H.A2017185.h16v07.006.2017192121405.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.30/MCD15A3H.A2017181.h16v07.006.2017191185250.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.26/MCD15A3H.A2017177.h16v07.006.2017187173403.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.22/MCD15A3H.A2017173.h16v07.006.2017178115905.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.18/MCD15A3H.A2017169.h16v07.006.2017174031010.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.14/MCD15A3H.A2017165.h16v07.006.2017171120915.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.10/MCD15A3H.A2017161.h16v07.006.2017171195704.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.06/MCD15A3H.A2017157.h16v07.006.2017164112532.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.02/MCD15A3H.A2017153.h16v07.006.2017164112459.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.29/MCD15A3H.A2017149.h16v07.006.2017164112437.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.25/MCD15A3H.A2017145.h16v07.006.2017151143810.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.21/MCD15A3H.A2017141.h16v07.006.2017146031609.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.17/MCD15A3H.A2017137.h16v07.006.2017142040131.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.13/MCD15A3H.A2017133.h16v07.006.2017138033758.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.09/MCD15A3H.A2017129.h16v07.006.2017137215640.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.05/MCD15A3H.A2017125.h16v07.006.2017135143755.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.01/MCD15A3H.A2017121.h16v07.006.2017126041927.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.27/MCD15A3H.A2017117.h16v07.006.2017122032702.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.23/MCD15A3H.A2017113.h16v07.006.2017118183845.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.19/MCD15A3H.A2017109.h16v07.006.2017118140141.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.15/MCD15A3H.A2017105.h16v07.006.2017118140118.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.11/MCD15A3H.A2017101.h16v07.006.2017116174705.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.07/MCD15A3H.A2017097.h16v07.006.2017104155001.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.03/MCD15A3H.A2017093.h16v07.006.2017104154923.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.30/MCD15A3H.A2017089.h16v07.006.2017095135324.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.26/MCD15A3H.A2017085.h16v07.006.2017094173842.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.22/MCD15A3H.A2017081.h16v07.006.2017087021009.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.18/MCD15A3H.A2017077.h16v07.006.2017082115656.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.14/MCD15A3H.A2017073.h16v07.006.2017082025537.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.10/MCD15A3H.A2017069.h16v07.006.2017080124358.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.06/MCD15A3H.A2017065.h16v07.006.2017073194948.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.02/MCD15A3H.A2017061.h16v07.006.2017066071006.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.26/MCD15A3H.A2017057.h16v07.006.2017065212511.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.22/MCD15A3H.A2017053.h16v07.006.2017059114734.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.18/MCD15A3H.A2017049.h16v07.006.2017059114650.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.14/MCD15A3H.A2017045.h16v07.006.2017053101210.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.10/MCD15A3H.A2017041.h16v07.006.2017047163942.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.06/MCD15A3H.A2017037.h16v07.006.2017045203221.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.02/MCD15A3H.A2017033.h16v07.006.2017040180853.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.29/MCD15A3H.A2017029.h16v07.006.2017040035845.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.25/MCD15A3H.A2017025.h16v07.006.2017031144736.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.21/MCD15A3H.A2017021.h16v07.006.2017031131455.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.17/MCD15A3H.A2017017.h16v07.006.2017024073837.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.13/MCD15A3H.A2017013.h16v07.006.2017021013434.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.09/MCD15A3H.A2017009.h16v07.006.2017018072239.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.05/MCD15A3H.A2017005.h16v07.006.2017017141804.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.01/MCD15A3H.A2017001.h16v07.006.2017014004827.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2016.12.26/MCD15A3H.A2016361.h16v07.006.2017010015135.hdf
EDSCEOF