#!/usr/bin/env python
from persiantools.jdatetime import JalaliDate
date = JalaliDate.today()
date.locale = "en"
FMT = '{"month": "%B", "day": "%A", "day_num": "%d", "year": "%Y", "pretty": "%A, %d %B"}'
print(date.strftime(FMT))
