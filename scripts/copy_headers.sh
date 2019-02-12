idir=$1
odir=$2

if [ ! -d "$idir" ]; then
echo input directory not found
exit 1
fi

if [ ! -d "$odir" ]; then
echo output directory not found
exit 1
fi

cd $idir

rsync -avm --include='*.h' -f 'hide,! */' . $odir