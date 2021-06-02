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
    echo "https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.31/MCD15A3H.A2017365.h21v08.006.2018005032642.hdf"
    echo
    exit 1
}

prompt_credentials
  detect_app_approval() {
    approved=`curl -s -b "$cookiejar" -c "$cookiejar" -L --max-redirs 2 --netrc-file "$netrc" https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.31/MCD15A3H.A2017365.h21v08.006.2018005032642.hdf -w %{http_code} | tail  -1`
    if [ "$approved" -ne "302" ]; then
        # User didn't approve the app. Direct users to approve the app in URS
        exit_with_error "Please ensure that you have authorized the remote application by visiting the link below "
    fi
}

setup_auth_curl() {
    # Firstly, check if it require URS authentication
    status=$(curl -s -z "$(date)" -w %{http_code} https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.31/MCD15A3H.A2017365.h21v08.006.2018005032642.hdf | tail -1)
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
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.31/MCD15A3H.A2017365.h21v08.006.2018005032642.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.27/MCD15A3H.A2017361.h21v08.006.2018002204011.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.23/MCD15A3H.A2017357.h21v08.006.2018002133715.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.19/MCD15A3H.A2017353.h21v08.006.2017361223401.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.15/MCD15A3H.A2017349.h21v08.006.2017354025752.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.11/MCD15A3H.A2017345.h21v08.006.2017353214002.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.07/MCD15A3H.A2017341.h21v08.006.2017346032221.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.03/MCD15A3H.A2017337.h21v08.006.2017342030705.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.29/MCD15A3H.A2017333.h21v08.006.2017341183712.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.25/MCD15A3H.A2017329.h21v08.006.2017334154348.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.21/MCD15A3H.A2017325.h21v08.006.2017333160940.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.17/MCD15A3H.A2017321.h21v08.006.2017331211547.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.13/MCD15A3H.A2017317.h21v08.006.2017331160725.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.09/MCD15A3H.A2017313.h21v08.006.2017325161840.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.05/MCD15A3H.A2017309.h21v08.006.2017314040557.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.11.01/MCD15A3H.A2017305.h21v08.006.2017312184720.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.28/MCD15A3H.A2017301.h21v08.006.2017310191413.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.24/MCD15A3H.A2017297.h21v08.006.2017303195412.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.20/MCD15A3H.A2017293.h21v08.006.2017300140824.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.16/MCD15A3H.A2017289.h21v08.006.2017297185545.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.12/MCD15A3H.A2017285.h21v08.006.2017290125955.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.08/MCD15A3H.A2017281.h21v08.006.2017286040838.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.10.04/MCD15A3H.A2017277.h21v08.006.2017283110808.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.30/MCD15A3H.A2017273.h21v08.006.2017278031459.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.26/MCD15A3H.A2017269.h21v08.006.2017276172452.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.22/MCD15A3H.A2017265.h21v08.006.2017271135330.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.18/MCD15A3H.A2017261.h21v08.006.2017266034530.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.14/MCD15A3H.A2017257.h21v08.006.2017262125223.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.10/MCD15A3H.A2017253.h21v08.006.2017258030452.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.06/MCD15A3H.A2017249.h21v08.006.2017254030933.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.09.02/MCD15A3H.A2017245.h21v08.006.2017250143559.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.29/MCD15A3H.A2017241.h21v08.006.2017249173900.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.25/MCD15A3H.A2017237.h21v08.006.2017242030814.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.21/MCD15A3H.A2017233.h21v08.006.2017248101421.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.17/MCD15A3H.A2017229.h21v08.006.2017234150007.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.13/MCD15A3H.A2017225.h21v08.006.2017230031503.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.09/MCD15A3H.A2017221.h21v08.006.2017227172146.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.05/MCD15A3H.A2017217.h21v08.006.2017227125043.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.08.01/MCD15A3H.A2017213.h21v08.006.2017227125015.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.28/MCD15A3H.A2017209.h21v08.006.2017214184737.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.24/MCD15A3H.A2017205.h21v08.006.2017212195606.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.20/MCD15A3H.A2017201.h21v08.006.2017212170618.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.16/MCD15A3H.A2017197.h21v08.006.2017202030610.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.12/MCD15A3H.A2017193.h21v08.006.2017198204716.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.08/MCD15A3H.A2017189.h21v08.006.2017194104642.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.07.04/MCD15A3H.A2017185.h21v08.006.2017192121412.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.30/MCD15A3H.A2017181.h21v08.006.2017191185308.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.26/MCD15A3H.A2017177.h21v08.006.2017187174451.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.22/MCD15A3H.A2017173.h21v08.006.2017178120735.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.18/MCD15A3H.A2017169.h21v08.006.2017174030820.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.14/MCD15A3H.A2017165.h21v08.006.2017171120916.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.10/MCD15A3H.A2017161.h21v08.006.2017171195904.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.06/MCD15A3H.A2017157.h21v08.006.2017164112542.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.06.02/MCD15A3H.A2017153.h21v08.006.2017164112510.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.29/MCD15A3H.A2017149.h21v08.006.2017164112444.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.25/MCD15A3H.A2017145.h21v08.006.2017151144012.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.21/MCD15A3H.A2017141.h21v08.006.2017146031001.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.17/MCD15A3H.A2017137.h21v08.006.2017142040238.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.13/MCD15A3H.A2017133.h21v08.006.2017138033317.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.09/MCD15A3H.A2017129.h21v08.006.2017137221343.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.05/MCD15A3H.A2017125.h21v08.006.2017135143231.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.05.01/MCD15A3H.A2017121.h21v08.006.2017126042052.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.27/MCD15A3H.A2017117.h21v08.006.2017122034623.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.23/MCD15A3H.A2017113.h21v08.006.2017118183802.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.19/MCD15A3H.A2017109.h21v08.006.2017118140202.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.15/MCD15A3H.A2017105.h21v08.006.2017118140116.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.11/MCD15A3H.A2017101.h21v08.006.2017116174429.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.07/MCD15A3H.A2017097.h21v08.006.2017104155023.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.04.03/MCD15A3H.A2017093.h21v08.006.2017104154948.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.30/MCD15A3H.A2017089.h21v08.006.2017095135558.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.26/MCD15A3H.A2017085.h21v08.006.2017094173351.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.22/MCD15A3H.A2017081.h21v08.006.2017087022559.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.18/MCD15A3H.A2017077.h21v08.006.2017082121232.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.14/MCD15A3H.A2017073.h21v08.006.2017082030729.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.10/MCD15A3H.A2017069.h21v08.006.2017080124409.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.06/MCD15A3H.A2017065.h21v08.006.2017073193430.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.03.02/MCD15A3H.A2017061.h21v08.006.2017066072139.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.26/MCD15A3H.A2017057.h21v08.006.2017065214059.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.22/MCD15A3H.A2017053.h21v08.006.2017059114727.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.18/MCD15A3H.A2017049.h21v08.006.2017059114624.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.14/MCD15A3H.A2017045.h21v08.006.2017053101226.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.10/MCD15A3H.A2017041.h21v08.006.2017047164027.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.06/MCD15A3H.A2017037.h21v08.006.2017045204026.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.02.02/MCD15A3H.A2017033.h21v08.006.2017040180908.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.29/MCD15A3H.A2017029.h21v08.006.2017040040355.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.25/MCD15A3H.A2017025.h21v08.006.2017031145315.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.21/MCD15A3H.A2017021.h21v08.006.2017031131543.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.17/MCD15A3H.A2017017.h21v08.006.2017024073848.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.13/MCD15A3H.A2017013.h21v08.006.2017021014016.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.09/MCD15A3H.A2017009.h21v08.006.2017018072314.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.05/MCD15A3H.A2017005.h21v08.006.2017017141856.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.01.01/MCD15A3H.A2017001.h21v08.006.2017014005420.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2016.12.26/MCD15A3H.A2016361.h21v08.006.2017010020701.hdf
EDSCEOF