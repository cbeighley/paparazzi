load('../../../var/logs/gyro_results.txt');

gyro_mean = round(mean(gyro_results))

save '../../../gyro_results.txt' gyro_mean
