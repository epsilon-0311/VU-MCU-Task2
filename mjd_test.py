
START_YEAR=2018
MJD_1ST_JANUARY_2018  = 58119;
MONTHS_OF_YEAR = [31,28,31,30,31,30,31,31,30,31,30,31]
LEAP_YEAR_DISTANCE = 4
NEXT_LEAP_YEAR = 2;
DAYS_IN_YEAR = 365
DAYS_IN_LEAP_YEAR = 366
MONTHS_IN_YEAR =  12
LEAP_MONTH = 1
LEAP_MONTH_DAYS = 29


counter=NEXT_LEAP_YEAR
MJD = 77111
current_year = START_YEAR
current_month =0
current_day =0

is_leap_year = False;

MJD -= MJD_1ST_JANUARY_2018

while( MJD >= DAYS_IN_YEAR):
    counter += 1
    counter %= LEAP_YEAR_DISTANCE

    if(counter==0):
        is_leap_year = True
        MJD-=DAYS_IN_YEAR
    elif(is_leap_year):
        MJD-=DAYS_IN_LEAP_YEAR
        is_leap_year = False
    else:
        MJD-=DAYS_IN_YEAR
        is_leap_year = False

    current_year +=1


for counter in range(12):

    if(is_leap_year and counter == LEAP_MONTH):

        if(MJD >= LEAP_MONTH_DAYS):
            MJD -= LEAP_MONTH_DAYS
        else:
            current_month=counter+1
            current_day = MJD+1
            break
    elif(MJD > MONTHS_OF_YEAR[counter]):
        MJD -= MONTHS_OF_YEAR[counter]
    else:
        current_month=counter+1
        current_day = MJD+1
        break

print current_day
print current_month
print current_year
