// 이 파일은 생성 파일이다. 직접 고치지 말고 아래 절차로 다시 만든다.
//
// 출처: korean-lunar-calendar 0.3.1 (PyPI, MIT, https://github.com/usingsky/korean_lunar_calendar_py)
//   sdist korean_lunar_calendar-0.3.1.tar.gz
//   sha256 eb2c485124a061016926bdea6d89efdf9b9fdbf16db55895b6cf1e5bec17b857
//   한국천문연구원(KASI) 기준 데이터 KOREAN_LUNAR_DATA 에서 음력 1900~2050년만 뽑았다.
// 재생성: 패키지를 빈 임시 폴더에 받아 풀고, 프로젝트 밖의 추출 스크립트를 python3 -I 로 실행해
//   (1) 연도별 값을 뽑고 (2) 뽑은 표로 변환한 결과를 패키지 변환 결과와 양력 1900-01-31 ~ 2050-12-31
//   모든 날짜에서 대조한 뒤 (불일치 0) 이 파일을 쓰고, make format 으로 포맷한다.
//
// 원본 라이선스 (MIT):
//
// Copyright (c) 2018-2020 Jinil Lee <usingsky@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

extension KoreanLunarCalendar {
  /// 음력 한 해의 정보.
  struct YearEntry: Sendable {
    /// 음력 연도
    let year: Int
    /// 그해 음력 1월 1일의 양력 날짜. 음력 설날은 늘 같은 양력 연도의 1~2월이다
    let newYear: CalendarDay
    /// 윤달이 붙는 달. 0 이면 윤달 없음
    let leapMonth: Int
    /// 달 순서(윤달은 같은 번호 평달 바로 뒤)대로 비트 0 부터: 1 = 큰달(30일), 0 = 작은달(29일)
    let monthSizeBits: UInt16

    init(year: Int, newYearMonth: Int, newYearDay: Int, leapMonth: Int, monthSizeBits: UInt16) {
      self.year = year
      self.newYear = CalendarDay(unchecked: year, newYearMonth, newYearDay)
      self.leapMonth = leapMonth
      self.monthSizeBits = monthSizeBits
    }
  }

  /// 음력 1900~2050년 표. 인덱스 = 음력 연도 - 1900.
  static let table: [YearEntry] = [
    YearEntry(year: 1900, newYearMonth: 1, newYearDay: 31, leapMonth: 8, monthSizeBits: 0b1_0110_1101_0010),
    YearEntry(year: 1901, newYearMonth: 2, newYearDay: 19, leapMonth: 0, monthSizeBits: 0b0111_0101_0010),
    YearEntry(year: 1902, newYearMonth: 2, newYearDay: 8, leapMonth: 0, monthSizeBits: 0b1110_1010_0101),
    YearEntry(year: 1903, newYearMonth: 1, newYearDay: 29, leapMonth: 5, monthSizeBits: 0b1_0110_0100_1010),
    YearEntry(year: 1904, newYearMonth: 2, newYearDay: 16, leapMonth: 0, monthSizeBits: 0b0110_0100_1011),
    YearEntry(year: 1905, newYearMonth: 2, newYearDay: 4, leapMonth: 0, monthSizeBits: 0b1010_1001_1011),
    YearEntry(year: 1906, newYearMonth: 1, newYearDay: 25, leapMonth: 4, monthSizeBits: 0b1_0101_0101_0110),
    YearEntry(year: 1907, newYearMonth: 2, newYearDay: 13, leapMonth: 0, monthSizeBits: 0b0101_0110_1010),
    YearEntry(year: 1908, newYearMonth: 2, newYearDay: 2, leapMonth: 0, monthSizeBits: 0b1011_0101_1001),
    YearEntry(year: 1909, newYearMonth: 1, newYearDay: 22, leapMonth: 2, monthSizeBits: 0b1_0111_0101_0010),
    YearEntry(year: 1910, newYearMonth: 2, newYearDay: 10, leapMonth: 0, monthSizeBits: 0b0111_0101_0010),
    YearEntry(year: 1911, newYearMonth: 1, newYearDay: 30, leapMonth: 6, monthSizeBits: 0b1_1011_0010_0101),
    YearEntry(year: 1912, newYearMonth: 2, newYearDay: 18, leapMonth: 0, monthSizeBits: 0b1011_0010_0101),
    YearEntry(year: 1913, newYearMonth: 2, newYearDay: 6, leapMonth: 0, monthSizeBits: 0b1010_0100_1011),
    YearEntry(year: 1914, newYearMonth: 1, newYearDay: 26, leapMonth: 5, monthSizeBits: 0b1_0010_1001_1011),
    YearEntry(year: 1915, newYearMonth: 2, newYearDay: 14, leapMonth: 0, monthSizeBits: 0b1010_1010_1101),
    YearEntry(year: 1916, newYearMonth: 2, newYearDay: 4, leapMonth: 0, monthSizeBits: 0b0101_0110_1010),
    YearEntry(year: 1917, newYearMonth: 1, newYearDay: 23, leapMonth: 2, monthSizeBits: 0b0_1011_0110_1001),
    YearEntry(year: 1918, newYearMonth: 2, newYearDay: 11, leapMonth: 0, monthSizeBits: 0b1011_1010_1001),
    YearEntry(year: 1919, newYearMonth: 2, newYearDay: 1, leapMonth: 7, monthSizeBits: 0b1_1011_0101_0010),
    YearEntry(year: 1920, newYearMonth: 2, newYearDay: 20, leapMonth: 0, monthSizeBits: 0b1101_1001_0010),
    YearEntry(year: 1921, newYearMonth: 2, newYearDay: 8, leapMonth: 0, monthSizeBits: 0b1101_0010_0101),
    YearEntry(year: 1922, newYearMonth: 1, newYearDay: 28, leapMonth: 5, monthSizeBits: 0b1_1010_0100_1101),
    YearEntry(year: 1923, newYearMonth: 2, newYearDay: 16, leapMonth: 0, monthSizeBits: 0b1001_0101_0110),
    YearEntry(year: 1924, newYearMonth: 2, newYearDay: 5, leapMonth: 0, monthSizeBits: 0b0010_1011_0101),
    YearEntry(year: 1925, newYearMonth: 1, newYearDay: 24, leapMonth: 4, monthSizeBits: 0b1_0101_1010_1101),
    YearEntry(year: 1926, newYearMonth: 2, newYearDay: 13, leapMonth: 0, monthSizeBits: 0b0110_1101_0100),
    YearEntry(year: 1927, newYearMonth: 2, newYearDay: 2, leapMonth: 0, monthSizeBits: 0b1101_1010_1001),
    YearEntry(year: 1928, newYearMonth: 1, newYearDay: 23, leapMonth: 2, monthSizeBits: 0b1_1101_1001_0010),
    YearEntry(year: 1929, newYearMonth: 2, newYearDay: 10, leapMonth: 0, monthSizeBits: 0b1110_1001_0010),
    YearEntry(year: 1930, newYearMonth: 1, newYearDay: 30, leapMonth: 6, monthSizeBits: 0b0_1101_0010_0110),
    YearEntry(year: 1931, newYearMonth: 2, newYearDay: 17, leapMonth: 0, monthSizeBits: 0b0101_0010_0111),
    YearEntry(year: 1932, newYearMonth: 2, newYearDay: 6, leapMonth: 0, monthSizeBits: 0b1010_0101_0111),
    YearEntry(year: 1933, newYearMonth: 1, newYearDay: 26, leapMonth: 5, monthSizeBits: 0b1_0010_1011_0110),
    YearEntry(year: 1934, newYearMonth: 2, newYearDay: 14, leapMonth: 0, monthSizeBits: 0b1010_1101_1010),
    YearEntry(year: 1935, newYearMonth: 2, newYearDay: 4, leapMonth: 0, monthSizeBits: 0b0110_1101_0100),
    YearEntry(year: 1936, newYearMonth: 1, newYearDay: 24, leapMonth: 3, monthSizeBits: 0b0_1110_1010_1001),
    YearEntry(year: 1937, newYearMonth: 2, newYearDay: 11, leapMonth: 0, monthSizeBits: 0b0111_0100_1001),
    YearEntry(year: 1938, newYearMonth: 1, newYearDay: 31, leapMonth: 7, monthSizeBits: 0b1_0110_1001_0011),
    YearEntry(year: 1939, newYearMonth: 2, newYearDay: 19, leapMonth: 0, monthSizeBits: 0b1010_1001_0011),
    YearEntry(year: 1940, newYearMonth: 2, newYearDay: 8, leapMonth: 0, monthSizeBits: 0b0101_0010_1011),
    YearEntry(year: 1941, newYearMonth: 1, newYearDay: 27, leapMonth: 6, monthSizeBits: 0b0_1010_0101_1011),
    YearEntry(year: 1942, newYearMonth: 2, newYearDay: 15, leapMonth: 0, monthSizeBits: 0b1001_0110_1101),
    YearEntry(year: 1943, newYearMonth: 2, newYearDay: 5, leapMonth: 0, monthSizeBits: 0b1011_0110_1010),
    YearEntry(year: 1944, newYearMonth: 1, newYearDay: 26, leapMonth: 4, monthSizeBits: 0b1_1011_0101_0100),
    YearEntry(year: 1945, newYearMonth: 2, newYearDay: 13, leapMonth: 0, monthSizeBits: 0b1011_1010_0100),
    YearEntry(year: 1946, newYearMonth: 2, newYearDay: 2, leapMonth: 0, monthSizeBits: 0b1011_0100_1001),
    YearEntry(year: 1947, newYearMonth: 1, newYearDay: 22, leapMonth: 2, monthSizeBits: 0b1_1010_1001_0011),
    YearEntry(year: 1948, newYearMonth: 2, newYearDay: 10, leapMonth: 0, monthSizeBits: 0b1010_1001_0101),
    YearEntry(year: 1949, newYearMonth: 1, newYearDay: 29, leapMonth: 7, monthSizeBits: 0b1_0101_0010_1011),
    YearEntry(year: 1950, newYearMonth: 2, newYearDay: 17, leapMonth: 0, monthSizeBits: 0b0101_0010_1101),
    YearEntry(year: 1951, newYearMonth: 2, newYearDay: 6, leapMonth: 0, monthSizeBits: 0b1010_1010_1101),
    YearEntry(year: 1952, newYearMonth: 1, newYearDay: 27, leapMonth: 5, monthSizeBits: 0b1_0101_0110_1010),
    YearEntry(year: 1953, newYearMonth: 2, newYearDay: 14, leapMonth: 0, monthSizeBits: 0b1101_1011_0010),
    YearEntry(year: 1954, newYearMonth: 2, newYearDay: 4, leapMonth: 0, monthSizeBits: 0b1101_1010_0100),
    YearEntry(year: 1955, newYearMonth: 1, newYearDay: 24, leapMonth: 3, monthSizeBits: 0b1_1101_0100_1001),
    YearEntry(year: 1956, newYearMonth: 2, newYearDay: 12, leapMonth: 0, monthSizeBits: 0b1101_0100_1010),
    YearEntry(year: 1957, newYearMonth: 1, newYearDay: 31, leapMonth: 8, monthSizeBits: 0b1_1010_1001_0101),
    YearEntry(year: 1958, newYearMonth: 2, newYearDay: 19, leapMonth: 0, monthSizeBits: 0b1010_1001_0110),
    YearEntry(year: 1959, newYearMonth: 2, newYearDay: 8, leapMonth: 0, monthSizeBits: 0b0101_0101_0110),
    YearEntry(year: 1960, newYearMonth: 1, newYearDay: 28, leapMonth: 6, monthSizeBits: 0b0_1010_1011_0101),
    YearEntry(year: 1961, newYearMonth: 2, newYearDay: 15, leapMonth: 0, monthSizeBits: 0b1010_1101_0101),
    YearEntry(year: 1962, newYearMonth: 2, newYearDay: 5, leapMonth: 0, monthSizeBits: 0b0110_1101_0010),
    YearEntry(year: 1963, newYearMonth: 1, newYearDay: 25, leapMonth: 4, monthSizeBits: 0b0_1110_1010_0101),
    YearEntry(year: 1964, newYearMonth: 2, newYearDay: 13, leapMonth: 0, monthSizeBits: 0b1110_1010_0101),
    YearEntry(year: 1965, newYearMonth: 2, newYearDay: 2, leapMonth: 0, monthSizeBits: 0b1110_0100_1010),
    YearEntry(year: 1966, newYearMonth: 1, newYearDay: 22, leapMonth: 3, monthSizeBits: 0b0_1100_1001_0110),
    YearEntry(year: 1967, newYearMonth: 2, newYearDay: 9, leapMonth: 0, monthSizeBits: 0b1010_1001_1011),
    YearEntry(year: 1968, newYearMonth: 1, newYearDay: 30, leapMonth: 7, monthSizeBits: 0b1_0101_0101_0110),
    YearEntry(year: 1969, newYearMonth: 2, newYearDay: 17, leapMonth: 0, monthSizeBits: 0b0101_0110_1010),
    YearEntry(year: 1970, newYearMonth: 2, newYearDay: 6, leapMonth: 0, monthSizeBits: 0b1011_0101_1001),
    YearEntry(year: 1971, newYearMonth: 1, newYearDay: 27, leapMonth: 5, monthSizeBits: 0b1_0111_0101_0010),
    YearEntry(year: 1972, newYearMonth: 2, newYearDay: 15, leapMonth: 0, monthSizeBits: 0b0111_0101_0010),
    YearEntry(year: 1973, newYearMonth: 2, newYearDay: 3, leapMonth: 0, monthSizeBits: 0b0111_0010_0101),
    YearEntry(year: 1974, newYearMonth: 1, newYearDay: 23, leapMonth: 4, monthSizeBits: 0b1_0110_0100_1011),
    YearEntry(year: 1975, newYearMonth: 2, newYearDay: 11, leapMonth: 0, monthSizeBits: 0b1010_0100_1011),
    YearEntry(year: 1976, newYearMonth: 1, newYearDay: 31, leapMonth: 8, monthSizeBits: 0b1_0010_1010_1011),
    YearEntry(year: 1977, newYearMonth: 2, newYearDay: 18, leapMonth: 0, monthSizeBits: 0b0010_1010_1101),
    YearEntry(year: 1978, newYearMonth: 2, newYearDay: 7, leapMonth: 0, monthSizeBits: 0b0101_0110_1011),
    YearEntry(year: 1979, newYearMonth: 1, newYearDay: 28, leapMonth: 6, monthSizeBits: 0b0_1011_0110_1001),
    YearEntry(year: 1980, newYearMonth: 2, newYearDay: 16, leapMonth: 0, monthSizeBits: 0b1101_1010_1001),
    YearEntry(year: 1981, newYearMonth: 2, newYearDay: 5, leapMonth: 0, monthSizeBits: 0b1101_1001_0010),
    YearEntry(year: 1982, newYearMonth: 1, newYearDay: 25, leapMonth: 4, monthSizeBits: 0b1_1011_0010_0101),
    YearEntry(year: 1983, newYearMonth: 2, newYearDay: 13, leapMonth: 0, monthSizeBits: 0b1101_0010_0101),
    YearEntry(year: 1984, newYearMonth: 2, newYearDay: 2, leapMonth: 10, monthSizeBits: 0b1_1010_0100_1101),
    YearEntry(year: 1985, newYearMonth: 2, newYearDay: 20, leapMonth: 0, monthSizeBits: 0b1010_0101_0110),
    YearEntry(year: 1986, newYearMonth: 2, newYearDay: 9, leapMonth: 0, monthSizeBits: 0b0010_1011_0110),
    YearEntry(year: 1987, newYearMonth: 1, newYearDay: 29, leapMonth: 6, monthSizeBits: 0b1_0101_1010_1101),
    YearEntry(year: 1988, newYearMonth: 2, newYearDay: 18, leapMonth: 0, monthSizeBits: 0b0110_1101_0100),
    YearEntry(year: 1989, newYearMonth: 2, newYearDay: 6, leapMonth: 0, monthSizeBits: 0b1101_1010_1001),
    YearEntry(year: 1990, newYearMonth: 1, newYearDay: 27, leapMonth: 5, monthSizeBits: 0b1_1101_1001_0010),
    YearEntry(year: 1991, newYearMonth: 2, newYearDay: 15, leapMonth: 0, monthSizeBits: 0b1110_1001_0010),
    YearEntry(year: 1992, newYearMonth: 2, newYearDay: 4, leapMonth: 0, monthSizeBits: 0b1101_0010_0110),
    YearEntry(year: 1993, newYearMonth: 1, newYearDay: 23, leapMonth: 3, monthSizeBits: 0b0_1010_0101_0110),
    YearEntry(year: 1994, newYearMonth: 2, newYearDay: 10, leapMonth: 0, monthSizeBits: 0b1010_0101_0111),
    YearEntry(year: 1995, newYearMonth: 1, newYearDay: 31, leapMonth: 8, monthSizeBits: 0b1_0010_1011_0110),
    YearEntry(year: 1996, newYearMonth: 2, newYearDay: 19, leapMonth: 0, monthSizeBits: 0b1011_0101_1010),
    YearEntry(year: 1997, newYearMonth: 2, newYearDay: 8, leapMonth: 0, monthSizeBits: 0b0110_1101_0100),
    YearEntry(year: 1998, newYearMonth: 1, newYearDay: 28, leapMonth: 5, monthSizeBits: 0b0_1110_1100_1001),
    YearEntry(year: 1999, newYearMonth: 2, newYearDay: 16, leapMonth: 0, monthSizeBits: 0b0111_0100_1001),
    YearEntry(year: 2000, newYearMonth: 2, newYearDay: 5, leapMonth: 0, monthSizeBits: 0b0110_1001_0011),
    YearEntry(year: 2001, newYearMonth: 1, newYearDay: 24, leapMonth: 4, monthSizeBits: 0b1_0101_0010_0111),
    YearEntry(year: 2002, newYearMonth: 2, newYearDay: 12, leapMonth: 0, monthSizeBits: 0b0101_0010_1011),
    YearEntry(year: 2003, newYearMonth: 2, newYearDay: 1, leapMonth: 0, monthSizeBits: 0b1010_0101_1011),
    YearEntry(year: 2004, newYearMonth: 1, newYearDay: 22, leapMonth: 2, monthSizeBits: 0b1_0101_0101_1010),
    YearEntry(year: 2005, newYearMonth: 2, newYearDay: 9, leapMonth: 0, monthSizeBits: 0b0011_0110_1010),
    YearEntry(year: 2006, newYearMonth: 1, newYearDay: 29, leapMonth: 7, monthSizeBits: 0b1_1011_0101_0101),
    YearEntry(year: 2007, newYearMonth: 2, newYearDay: 18, leapMonth: 0, monthSizeBits: 0b1011_1010_0100),
    YearEntry(year: 2008, newYearMonth: 2, newYearDay: 7, leapMonth: 0, monthSizeBits: 0b1011_0100_1001),
    YearEntry(year: 2009, newYearMonth: 1, newYearDay: 26, leapMonth: 5, monthSizeBits: 0b1_1010_1001_0011),
    YearEntry(year: 2010, newYearMonth: 2, newYearDay: 14, leapMonth: 0, monthSizeBits: 0b1010_1001_0101),
    YearEntry(year: 2011, newYearMonth: 2, newYearDay: 3, leapMonth: 0, monthSizeBits: 0b0101_0010_1101),
    YearEntry(year: 2012, newYearMonth: 1, newYearDay: 23, leapMonth: 3, monthSizeBits: 0b0_1010_0101_1101),
    YearEntry(year: 2013, newYearMonth: 2, newYearDay: 10, leapMonth: 0, monthSizeBits: 0b1010_1010_1101),
    YearEntry(year: 2014, newYearMonth: 1, newYearDay: 31, leapMonth: 9, monthSizeBits: 0b1_0101_1010_1010),
    YearEntry(year: 2015, newYearMonth: 2, newYearDay: 19, leapMonth: 0, monthSizeBits: 0b0101_1101_0010),
    YearEntry(year: 2016, newYearMonth: 2, newYearDay: 8, leapMonth: 0, monthSizeBits: 0b1101_1010_0101),
    YearEntry(year: 2017, newYearMonth: 1, newYearDay: 28, leapMonth: 5, monthSizeBits: 0b1_1101_0100_1010),
    YearEntry(year: 2018, newYearMonth: 2, newYearDay: 16, leapMonth: 0, monthSizeBits: 0b1101_0100_1010),
    YearEntry(year: 2019, newYearMonth: 2, newYearDay: 5, leapMonth: 0, monthSizeBits: 0b1010_1001_0101),
    YearEntry(year: 2020, newYearMonth: 1, newYearDay: 25, leapMonth: 4, monthSizeBits: 0b1_0101_0010_1101),
    YearEntry(year: 2021, newYearMonth: 2, newYearDay: 12, leapMonth: 0, monthSizeBits: 0b0101_0101_0110),
    YearEntry(year: 2022, newYearMonth: 2, newYearDay: 1, leapMonth: 0, monthSizeBits: 0b1010_1011_0101),
    YearEntry(year: 2023, newYearMonth: 1, newYearDay: 22, leapMonth: 2, monthSizeBits: 0b1_0101_1010_1010),
    YearEntry(year: 2024, newYearMonth: 2, newYearDay: 10, leapMonth: 0, monthSizeBits: 0b0110_1101_0010),
    YearEntry(year: 2025, newYearMonth: 1, newYearDay: 29, leapMonth: 6, monthSizeBits: 0b0_1110_1010_0101),
    YearEntry(year: 2026, newYearMonth: 2, newYearDay: 17, leapMonth: 0, monthSizeBits: 0b1110_1010_0101),
    YearEntry(year: 2027, newYearMonth: 2, newYearDay: 7, leapMonth: 0, monthSizeBits: 0b1110_0100_1010),
    YearEntry(year: 2028, newYearMonth: 1, newYearDay: 27, leapMonth: 5, monthSizeBits: 0b0_1100_1001_0110),
    YearEntry(year: 2029, newYearMonth: 2, newYearDay: 13, leapMonth: 0, monthSizeBits: 0b1100_1001_1011),
    YearEntry(year: 2030, newYearMonth: 2, newYearDay: 3, leapMonth: 0, monthSizeBits: 0b0101_0101_1010),
    YearEntry(year: 2031, newYearMonth: 1, newYearDay: 23, leapMonth: 3, monthSizeBits: 0b0_1010_1101_0101),
    YearEntry(year: 2032, newYearMonth: 2, newYearDay: 11, leapMonth: 0, monthSizeBits: 0b1011_0110_1001),
    YearEntry(year: 2033, newYearMonth: 1, newYearDay: 31, leapMonth: 11, monthSizeBits: 0b1_0111_0101_0010),
    YearEntry(year: 2034, newYearMonth: 2, newYearDay: 19, leapMonth: 0, monthSizeBits: 0b0111_0101_0010),
    YearEntry(year: 2035, newYearMonth: 2, newYearDay: 8, leapMonth: 0, monthSizeBits: 0b1011_0010_0101),
    YearEntry(year: 2036, newYearMonth: 1, newYearDay: 28, leapMonth: 6, monthSizeBits: 0b1_0110_0100_1011),
    YearEntry(year: 2037, newYearMonth: 2, newYearDay: 15, leapMonth: 0, monthSizeBits: 0b1010_0100_1011),
    YearEntry(year: 2038, newYearMonth: 2, newYearDay: 4, leapMonth: 0, monthSizeBits: 0b0100_1010_1011),
    YearEntry(year: 2039, newYearMonth: 1, newYearDay: 24, leapMonth: 5, monthSizeBits: 0b0_0101_0101_1011),
    YearEntry(year: 2040, newYearMonth: 2, newYearDay: 12, leapMonth: 0, monthSizeBits: 0b0101_0110_1101),
    YearEntry(year: 2041, newYearMonth: 2, newYearDay: 1, leapMonth: 0, monthSizeBits: 0b1011_0110_1001),
    YearEntry(year: 2042, newYearMonth: 1, newYearDay: 22, leapMonth: 2, monthSizeBits: 0b1_1011_0101_0010),
    YearEntry(year: 2043, newYearMonth: 2, newYearDay: 10, leapMonth: 0, monthSizeBits: 0b1101_1001_0010),
    YearEntry(year: 2044, newYearMonth: 1, newYearDay: 30, leapMonth: 7, monthSizeBits: 0b1_1101_0010_0101),
    YearEntry(year: 2045, newYearMonth: 2, newYearDay: 17, leapMonth: 0, monthSizeBits: 0b1101_0010_0101),
    YearEntry(year: 2046, newYearMonth: 2, newYearDay: 6, leapMonth: 0, monthSizeBits: 0b1010_0100_1101),
    YearEntry(year: 2047, newYearMonth: 1, newYearDay: 26, leapMonth: 5, monthSizeBits: 0b1_0100_1010_1101),
    YearEntry(year: 2048, newYearMonth: 2, newYearDay: 14, leapMonth: 0, monthSizeBits: 0b0010_1011_0110),
    YearEntry(year: 2049, newYearMonth: 2, newYearDay: 2, leapMonth: 0, monthSizeBits: 0b0101_1011_0101),
    YearEntry(year: 2050, newYearMonth: 1, newYearDay: 23, leapMonth: 3, monthSizeBits: 0b0_1101_1010_1001),
  ]
}
