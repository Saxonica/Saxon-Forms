#!/bin/sh
TRANG=lib/trang.jar

if [ ! -e $TRANG ] ;
then
  echo "Missing $TRANG"
  exit -1
fi

# convert RNC to RNG
for RNC in *.rnc
do
RNG=`echo $RNC | sed -e 's/\.rnc$/\.rng/'`
echo java -jar $TRANG -I rnc -O rng $RNC $RNG
done

# delete any RNG files copied from elsewhere by trang
for RNG in *.rng
do
RNC=`echo $RNG | sed -e 's/\.rng$/\.rnc/'`
if [ ! -e $RNC ] ;
then
  rm $RNG
fi
done
