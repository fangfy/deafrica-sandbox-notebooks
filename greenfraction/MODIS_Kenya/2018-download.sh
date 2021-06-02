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
    echo "https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.31/MCD15A3H.A2018365.h21v08.006.2019014203432.hdf"
    echo
    exit 1
}

prompt_credentials
  detect_app_approval() {
    approved=`curl -s -b "$cookiejar" -c "$cookiejar" -L --max-redirs 2 --netrc-file "$netrc" https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.31/MCD15A3H.A2018365.h21v08.006.2019014203432.hdf -w %{http_code} | tail  -1`
    if [ "$approved" -ne "302" ]; then
        # User didn't approve the app. Direct users to approve the app in URS
        exit_with_error "Please ensure that you have authorized the remote application by visiting the link below "
    fi
}

setup_auth_curl() {
    # Firstly, check if it require URS authentication
    status=$(curl -s -z "$(date)" -w %{http_code} https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.31/MCD15A3H.A2018365.h21v08.006.2019014203432.hdf | tail -1)
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
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.31/MCD15A3H.A2018365.h21v08.006.2019014203432.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.27/MCD15A3H.A2018361.h21v08.006.2019014203327.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.23/MCD15A3H.A2018357.h21v08.006.2019032193710.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.19/MCD15A3H.A2018353.h21v08.006.2019007205154.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.15/MCD15A3H.A2018349.h21v08.006.2019004161746.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.11/MCD15A3H.A2018345.h21v08.006.2019004161728.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.07/MCD15A3H.A2018341.h21v08.006.2019004161630.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.12.03/MCD15A3H.A2018337.h21v08.006.2018348151549.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.11.29/MCD15A3H.A2018333.h21v08.006.2018338134310.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.11.25/MCD15A3H.A2018329.h21v08.006.2018334033424.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.11.21/MCD15A3H.A2018325.h21v08.006.2018331122600.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.11.17/MCD15A3H.A2018321.h21v08.006.2018330222217.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.11.13/MCD15A3H.A2018317.h21v08.006.2018324153014.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.11.09/MCD15A3H.A2018313.h21v08.006.2018318033826.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.11.05/MCD15A3H.A2018309.h21v08.006.2018314033225.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.11.01/MCD15A3H.A2018305.h21v08.006.2018313165900.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.10.28/MCD15A3H.A2018301.h21v08.006.2018313165819.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.10.24/MCD15A3H.A2018297.h21v08.006.2018303121249.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.10.20/MCD15A3H.A2018293.h21v08.006.2018298034557.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.10.16/MCD15A3H.A2018289.h21v08.006.2018296125209.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.10.12/MCD15A3H.A2018285.h21v08.006.2018296125146.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.10.08/MCD15A3H.A2018281.h21v08.006.2018296125120.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.10.04/MCD15A3H.A2018277.h21v08.006.2018289144902.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.09.30/MCD15A3H.A2018273.h21v08.006.2018278143639.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.09.26/MCD15A3H.A2018269.h21v08.006.2018276225427.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.09.22/MCD15A3H.A2018265.h21v08.006.2018270040109.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.09.18/MCD15A3H.A2018261.h21v08.006.2018267201848.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.09.14/MCD15A3H.A2018257.h21v08.006.2018263153120.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.09.10/MCD15A3H.A2018253.h21v08.006.2018258040110.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.09.06/MCD15A3H.A2018249.h21v08.006.2018254035122.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.09.02/MCD15A3H.A2018245.h21v08.006.2018250035341.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.08.29/MCD15A3H.A2018241.h21v08.006.2018247182840.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.08.25/MCD15A3H.A2018237.h21v08.006.2018242034010.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.08.21/MCD15A3H.A2018233.h21v08.006.2018239134506.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.08.17/MCD15A3H.A2018229.h21v08.006.2018235185023.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.08.13/MCD15A3H.A2018225.h21v08.006.2018233131704.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.08.09/MCD15A3H.A2018221.h21v08.006.2018232185622.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.08.05/MCD15A3H.A2018217.h21v08.006.2018226155419.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.08.01/MCD15A3H.A2018213.h21v08.006.2018220205933.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.07.28/MCD15A3H.A2018209.h21v08.006.2018214035243.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.07.24/MCD15A3H.A2018205.h21v08.006.2018210035921.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.07.20/MCD15A3H.A2018201.h21v08.006.2018206172545.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.07.16/MCD15A3H.A2018197.h21v08.006.2018202035133.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.07.12/MCD15A3H.A2018193.h21v08.006.2018199143206.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.07.08/MCD15A3H.A2018189.h21v08.006.2018197141204.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.07.04/MCD15A3H.A2018185.h21v08.006.2018190141915.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.06.30/MCD15A3H.A2018181.h21v08.006.2018187144529.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.06.26/MCD15A3H.A2018177.h21v08.006.2018186152128.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.06.22/MCD15A3H.A2018173.h21v08.006.2018179140304.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.06.18/MCD15A3H.A2018169.h21v08.006.2018177163743.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.06.14/MCD15A3H.A2018165.h21v08.006.2018170034240.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.06.10/MCD15A3H.A2018161.h21v08.006.2018166205623.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.06.06/MCD15A3H.A2018157.h21v08.006.2018163123225.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.06.02/MCD15A3H.A2018153.h21v08.006.2018158180534.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.05.29/MCD15A3H.A2018149.h21v08.006.2018155143144.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.05.25/MCD15A3H.A2018145.h21v08.006.2018152145602.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.05.21/MCD15A3H.A2018141.h21v08.006.2018150234858.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.05.17/MCD15A3H.A2018137.h21v08.006.2018143211206.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.05.13/MCD15A3H.A2018133.h21v08.006.2018149170600.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.05.09/MCD15A3H.A2018129.h21v08.006.2018134033526.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.05.05/MCD15A3H.A2018125.h21v08.006.2018130032251.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.05.01/MCD15A3H.A2018121.h21v08.006.2018129232037.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.04.27/MCD15A3H.A2018117.h21v08.006.2018122033934.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.04.23/MCD15A3H.A2018113.h21v08.006.2018120222545.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.04.19/MCD15A3H.A2018109.h21v08.006.2018114155451.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.04.15/MCD15A3H.A2018105.h21v08.006.2018110150028.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.04.11/MCD15A3H.A2018101.h21v08.006.2018108182020.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.04.07/MCD15A3H.A2018097.h21v08.006.2018102033425.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.04.03/MCD15A3H.A2018093.h21v08.006.2018098032501.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.03.30/MCD15A3H.A2018089.h21v08.006.2018094175657.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.03.26/MCD15A3H.A2018085.h21v08.006.2018095162132.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.03.22/MCD15A3H.A2018081.h21v08.006.2018087161511.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.03.18/MCD15A3H.A2018077.h21v08.006.2018082205104.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.03.14/MCD15A3H.A2018073.h21v08.006.2018079201304.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.03.10/MCD15A3H.A2018069.h21v08.006.2018074032815.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.03.06/MCD15A3H.A2018065.h21v08.006.2018071231048.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.03.02/MCD15A3H.A2018061.h21v08.006.2018067145540.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.02.26/MCD15A3H.A2018057.h21v08.006.2018064222430.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.02.22/MCD15A3H.A2018053.h21v08.006.2018060155915.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.02.18/MCD15A3H.A2018049.h21v08.006.2018059162959.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.02.14/MCD15A3H.A2018045.h21v08.006.2018052091123.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.02.10/MCD15A3H.A2018041.h21v08.006.2018046030629.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.02.06/MCD15A3H.A2018037.h21v08.006.2018043202326.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.02.02/MCD15A3H.A2018033.h21v08.006.2018038032521.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.01.29/MCD15A3H.A2018029.h21v08.006.2018037131321.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.01.25/MCD15A3H.A2018025.h21v08.006.2018030230102.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.01.21/MCD15A3H.A2018021.h21v08.006.2018026195742.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.01.17/MCD15A3H.A2018017.h21v08.006.2018023204155.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.01.13/MCD15A3H.A2018013.h21v08.006.2018018150929.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.01.09/MCD15A3H.A2018009.h21v08.006.2018014032845.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.01.05/MCD15A3H.A2018005.h21v08.006.2018011144828.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2018.01.01/MCD15A3H.A2018001.h21v08.006.2018010161808.hdf
https://e4ftl01.cr.usgs.gov//MODV6_Cmp_A/MOTA/MCD15A3H.006/2017.12.27/MCD15A3H.A2017361.h21v08.006.2018002204011.hdf
EDSCEOF