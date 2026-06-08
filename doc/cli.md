|✅/❌| Option        |Type   | Explanation|
|-----|---------------|-------|------------|
|❌| -?          	| Flag  |print help |
|❌| -k file     	| List  |input options from configuration file [off] |
|❌| -o file     	| String|set output file [stdout] |
|❌| -ts ds ts   	| String|start day/time (ds=y/m/d ts=h:m:s) [obs start time] |
|❌| -te de te   	| String|end day/time   (de=y/m/d te=h:m:s) [obs end time] |
|❌| -ti tint    	| |time interval (sec) [all] |
|❌| -p mode     	| |mode (0:single,1:dgps,2:kinematic,3:static,4:static-start,5:moving-base,6:fixed,7:ppp-kinematic,8:ppp-static,9:ppp-fixed) [2] |
|❌| -m mask     	| |elevation mask angle (deg) [15] |
|❌| -sys s[,s...] | |nav system(s) (s=G:GPS,R:GLO,E:GAL,J:QZS,C:BDS,I:IRN) [G	|R] |
|❌| -f freq     	| |number of frequencies for relative mode (1:L1,2:L1+L2,3:L1+L2+L5) [2] |
|❌| -v thres    	| |validation threshold for integer ambiguity (0.0:no AR) [3.0] |
|❌| -b          	| Flag  |backward solutions [off] |
|❌| -c          	| Flag  |forward/backward combined solutions [off] |
|❌| -i          	| Flag  |instantaneous integer ambiguity resolution [off] |
|❌| -h          	| Flag  |fix and hold for integer ambiguity resolution [off] |
|❌| -bl bl,std  	| |baseline distance and stdev |
|❌| -e          	| Flag  |output x/y/z-ecef position [latitude/longitude/height] |
|❌| -a          	| Flag  |output e/n/u-baseline [latitude/longitude/height] |
|❌| -n          	| Flag  |output NMEA-0183 GGA sentence [off] |
|❌| -g          	| Flag  |output latitude/longitude in the form of ddd mm ss.ss' [ddd.ddd] |
|❌| -t          	| Flag  |output time in the form of yyyy/mm/dd hh:mm:ss.ss [sssss.ss] |
|❌| -u          	| Flag  |output time in utc [gpst] |
|❌| -d col      	| |number of decimals in time [3] |
|❌| -s sep      	| |field separator [' '] |
|❌| -r x y z    	| |reference (base) receiver ecef pos (m) [average of single pos] rover receiver ecef pos (m) for fixed or ppp-fixed mode |
|❌| -l lat lon hgt| |reference (base) receiver latitude/longitude/height (deg/m) rover latitude/longitude/height for fixed or ppp-fixed mode |
|❌| -y level    	| |output solution status (0:off,1:states,2:residuals) [0] |
|❌| -x level    	| |debug trace level (0:off) [0] |
|❌| --rover     	| Flag  |list rover names for processing, separated by a space |
|❌| --base      	| Flag  |list  base names for processing, separated by a space |
|❌| --version   	| Flag  |display release version |
