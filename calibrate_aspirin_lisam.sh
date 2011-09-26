#End paparazzi processes
if [ "$(pidof paparazzicenter)" ] 
then
	killall "paparazzicenter"
fi
if [ "$(pidof messages)" ] 
then
	killall "messages"
fi
if [ "$(pidof plotter)" ] 
then
	killall "plotter"
fi
if [ "$(pidof server)" ] 
then
	killall "server"
fi
if [ "$(pidof link)" ] 
then
	killall "link"
fi
#Prompt user
echo ''
echo 'Plug the USB cable into the LISA/M, another USB cable into the FLOSS JTAG, and a UART and JTAG cable from the FLOSS JTAG to the LISA/M and press enter'
echo ''
read
#Program LISA/M
make AIRCRAFT=LISA_M clean_ac test_imu_aspirin.upload
wait 1s
#Clear out logs directory
touch var/logs/tmp.txt
rm var/logs/*
#Run Paparazzi to get samples (accel and mag)
./paparazzi -session "Flight USB-serial@57600 USB1" &
#Prompt user
echo ''
echo 'Rotate the board through all 6 axes, stopping about 5 seconds at each axis. When done rotating the board through all 6 axes press enter. (getting data for mag and accel calibration)'
echo ''
read
#End paparazzi processes
if [ "$(pidof paparazzicenter)" ] 
then
	killall "paparazzicenter"
fi
if [ "$(pidof messages)" ] 
then
	killall "messages"
fi
if [ "$(pidof plotter)" ] 
then
	killall "plotter"
fi
if [ "$(pidof server)" ] 
then
	killall "server"
fi
if [ "$(pidof link)" ] 
then
	killall "link"
fi
#Get calibration values for accel and mag
cd sw/tools/calibration
./calibrate.py -s ACCEL ../../../var/logs/*.data -v
./calibrate.py -s MAG ../../../var/logs/*.data -v
./calibrate.py -s ACCEL ../../../var/logs/*.data -v > ../../../accel_results.txt
./calibrate.py -s MAG ../../../var/logs/*.data -v > ../../../mag_results.txt
cd ../../..

#Prompt user
echo ''
echo 'Place LISA/M on a stable surface, let go, and press enter (getting gyro neutral values). Let it sit until you are prompted again in 10 seconds.'
echo ''
read

#Clear out logs directory
touch var/logs/tmp.txt
rm var/logs/*

#Run Paparazzi to get samples (gyro)
./paparazzi -session "Flight USB-serial@57600 USB1" &
sleep 12s
if [ "$(pidof paparazzicenter)" ] 
then
	killall "paparazzicenter"
fi
if [ "$(pidof messages)" ] 
then
	killall "messages"
fi
if [ "$(pidof plotter)" ] 
then
	killall "plotter"
fi
if [ "$(pidof server)" ] 
then
	killall "server"
fi
if [ "$(pidof link)" ] 
then
	killall "link"
fi
grep "IMU_GYRO_RAW" var/logs/*.data | sed -e "s|^.*IMU_GYRO_RAW ||" > var/logs/gyro_results.txt
cd sw/tools/calibration
octave --eval gyro_mean
cd ../../..

#Find calibration values and replace them in calibration template file
#Create temp xml files
cp imu_template.xml tmp0.xml
touch tmp1.xml
#Create strings that show where to change values
accel_neutral_strs=('ACCEL_X_NEUTRAL' 'ACCEL_Y_NEUTRAL' 'ACCEL_Z_NEUTRAL')
mag_neutral_strs=('MAG_X_NEUTRAL' 'MAG_Y_NEUTRAL' 'MAG_Z_NEUTRAL')
gyro_neutral_strs=('GYRO_P_NEUTRAL' 'GYRO_Q_NEUTRAL' 'GYRO_R_NEUTRAL')
accel_sens_strs=('ACCEL_X_SENS' 'ACCEL_Y_SENS' 'ACCEL_Z_SENS')
mag_sens_strs=('MAG_X_SENS' 'MAG_Y_SENS' 'MAG_Z_SENS')

#Change accel neutral values in tmp file
for i in 0 1 2
do
	tmp=$(grep "${accel_neutral_strs[i]}" accel_results.txt | sed -e "s|.*value=\"\\([0-9-]*\)\"/>|\1|")
	sed -e "s|\(${accel_neutral_strs[i]}\" value=\"\)\([0-9-]*\)|\1$tmp|" tmp0.xml > tmp1.xml
	mv tmp1.xml tmp0.xml
done
#Change accel sens values in tmp file
for i in 0 1 2
do
	tmp=$(grep "${accel_sens_strs[i]}" accel_results.txt | sed -e "s|.*value=\"\\([0-9.]*\).*|\1|")
	sed -e "s|\(${accel_sens_strs[i]}\" value=\"\)\([0-9.]*\)|\1$tmp|" tmp0.xml > tmp1.xml
	mv tmp1.xml tmp0.xml
done
#Change mag neutral values in tmp file
for i in 0 1 2
do
	tmp=$(grep "${mag_neutral_strs[i]}" mag_results.txt | sed -e "s|.*value=\"\([0-9-]*\)\"/>|\1|")
	sed -e "s|\(${mag_neutral_strs[i]}\" value=\"\)\([0-9-]*\)|\1$tmp|" tmp0.xml > tmp1.xml
	mv tmp1.xml tmp0.xml
done
#Change mag sens values in tmp file
for i in 0 1 2
do
	tmp=$(grep "${mag_sens_strs[i]}" mag_results.txt | sed -e "s|.*value=\"\([0-9.]*\).*|\1|")
	sed -e "s|\(${mag_sens_strs[i]}\" value=\"\)\([0-9.]*\)|\1$tmp|" tmp0.xml > tmp1.xml
	mv tmp1.xml tmp0.xml
done
#Change gyro neutral values in tmp file
gyro_p=$(grep "^ " gyro_results.txt | sed -e "s|^ \([0-9-]*\) [0-9-]* [0-9-]*|\1|")
gyro_q=$(grep "^ " gyro_results.txt | sed -e "s|^ [0-9-]* \([0-9-]*\) [0-9-]*|\1|")
gyro_r=$(grep "^ " gyro_results.txt | sed -e "s|^ [0-9-]* [0-9-]* \([0-9-]*\)|\1|")
sed -e "s|\(${gyro_neutral_strs[0]}\" value=\"\)\([0-9-]*\)|\1$gyro_p|" tmp0.xml > tmp1.xml
mv tmp1.xml tmp0.xml
sed -e "s|\(${gyro_neutral_strs[1]}\" value=\"\)\([0-9-]*\)|\1$gyro_q|" tmp0.xml > tmp1.xml
mv tmp1.xml tmp0.xml
sed -e "s|\(${gyro_neutral_strs[2]}\" value=\"\)\([0-9-]*\)|\1$gyro_r|" tmp0.xml > tmp1.xml
mv tmp1.xml tmp0.xml

#Get serial number from user
echo 'Type LISA/M serial number and press enter'
echo ''
read serial_number
#Name configuration file for user's serial number
cp tmp0.xml imu_lisam_$serial_number.xml
echo ''
echo 'file name is imu_lisam_'$serial_number'.xml'
echo ''
cat imu_lisam_$serial_number.xml
mv imu_lisam_$serial_number.xml ../imu_confs/

#Clean up
rm mag_results.txt
rm accel_results.txt
rm gyro_results.txt
rm tmp0.xml

echo 'Done with configuration'
echo ''
