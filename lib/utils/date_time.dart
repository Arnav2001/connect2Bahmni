import '../screens/models/person_age.dart';

PersonAge calculateAge(DateTime birthDate) {
  DateTime today = DateTime.now();
  DateTime dob = birthDate;
  var diff = today.difference(dob);

  List<int> simpleYear = [31,28,31,30,31,30,31,31,30,31,30,31];
  if(dob.isAfter(today)) {
    DateTime temp = dob;
    dob = today;
    today = temp;
  }
  int totalMonthsDifference = ((today.year*12) + (today.month - 1)) - ((dob.year*12) + (dob.month - 1));
  int years = (totalMonthsDifference/12).floor();
  int months = totalMonthsDifference%12;
  late int days;
  if(today.day >= dob.day) {days = today.day - dob.day;}
  else {
    int monthDays = today.month == 3
        ? (isLeapYear(today.year)? 29: 28)
        : (today.month - 2 == -1? simpleYear[11]: simpleYear[today.month - 2]);
    int day = dob.day;
    if(day > monthDays) day = monthDays;
    days = monthDays - (day - today.day);
    months--;
  }
  if(months < 0) {
    months = 11;
    years--;
  }
  return PersonAge(years, months, days);
}

bool isLeapYear(int year) {
  if (year % 4 == 0) {
    if(year % 100 ==0) {
      return year % 400 == 0 ? true : false;
    }
    return true;
  }
  return false;
}