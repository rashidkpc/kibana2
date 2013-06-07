module TZInfo
  module Definitions
    module Pacific
      module Fiji
        include TimezoneDefinition
        
        timezone 'Pacific/Fiji' do |tz|
          tz.offset :o0, 42820, 0, :LMT
          tz.offset :o1, 43200, 0, :FJT
          tz.offset :o2, 43200, 3600, :FJST
          
          tz.transition 1915, 10, :o1, 10457838739, 4320
          tz.transition 1998, 10, :o2, 909842400
          tz.transition 1999, 2, :o1, 920124000
          tz.transition 1999, 11, :o2, 941896800
          tz.transition 2000, 2, :o1, 951573600
          tz.transition 2009, 11, :o2, 1259416800
          tz.transition 2010, 3, :o1, 1269698400
          tz.transition 2010, 10, :o2, 1287842400
          tz.transition 2011, 3, :o1, 1299333600
          tz.transition 2011, 10, :o2, 1319292000
          tz.transition 2012, 1, :o1, 1327154400
          tz.transition 2012, 10, :o2, 1350741600
          tz.transition 2013, 1, :o1, 1358604000
          tz.transition 2013, 10, :o2, 1382191200
          tz.transition 2014, 1, :o1, 1390053600
          tz.transition 2014, 10, :o2, 1413640800
          tz.transition 2015, 1, :o1, 1421503200
          tz.transition 2015, 10, :o2, 1445090400
          tz.transition 2016, 1, :o1, 1453557600
          tz.transition 2016, 10, :o2, 1477144800
          tz.transition 2017, 1, :o1, 1485007200
          tz.transition 2017, 10, :o2, 1508594400
          tz.transition 2018, 1, :o1, 1516456800
          tz.transition 2018, 10, :o2, 1540044000
          tz.transition 2019, 1, :o1, 1547906400
          tz.transition 2019, 10, :o2, 1571493600
          tz.transition 2020, 1, :o1, 1579356000
          tz.transition 2020, 10, :o2, 1602943200
          tz.transition 2021, 1, :o1, 1611410400
          tz.transition 2021, 10, :o2, 1634997600
          tz.transition 2022, 1, :o1, 1642860000
          tz.transition 2022, 10, :o2, 1666447200
          tz.transition 2023, 1, :o1, 1674309600
          tz.transition 2023, 10, :o2, 1697896800
          tz.transition 2024, 1, :o1, 1705759200
          tz.transition 2024, 10, :o2, 1729346400
          tz.transition 2025, 1, :o1, 1737208800
          tz.transition 2025, 10, :o2, 1760796000
          tz.transition 2026, 1, :o1, 1768658400
          tz.transition 2026, 10, :o2, 1792245600
          tz.transition 2027, 1, :o1, 1800712800
          tz.transition 2027, 10, :o2, 1824300000
          tz.transition 2028, 1, :o1, 1832162400
          tz.transition 2028, 10, :o2, 1855749600
          tz.transition 2029, 1, :o1, 1863612000
          tz.transition 2029, 10, :o2, 1887199200
          tz.transition 2030, 1, :o1, 1895061600
          tz.transition 2030, 10, :o2, 1918648800
          tz.transition 2031, 1, :o1, 1926511200
          tz.transition 2031, 10, :o2, 1950098400
          tz.transition 2032, 1, :o1, 1957960800
          tz.transition 2032, 10, :o2, 1982152800
          tz.transition 2033, 1, :o1, 1990015200
          tz.transition 2033, 10, :o2, 2013602400
          tz.transition 2034, 1, :o1, 2021464800
          tz.transition 2034, 10, :o2, 2045052000
          tz.transition 2035, 1, :o1, 2052914400
          tz.transition 2035, 10, :o2, 2076501600
          tz.transition 2036, 1, :o1, 2084364000
          tz.transition 2036, 10, :o2, 2107951200
          tz.transition 2037, 1, :o1, 2115813600
          tz.transition 2037, 10, :o2, 2139400800
          tz.transition 2038, 1, :o1, 29585365, 12
          tz.transition 2038, 10, :o2, 29588641, 12
          tz.transition 2039, 1, :o1, 29589733, 12
          tz.transition 2039, 10, :o2, 29593009, 12
          tz.transition 2040, 1, :o1, 29594101, 12
          tz.transition 2040, 10, :o2, 29597377, 12
          tz.transition 2041, 1, :o1, 29598469, 12
          tz.transition 2041, 10, :o2, 29601745, 12
          tz.transition 2042, 1, :o1, 29602837, 12
          tz.transition 2042, 10, :o2, 29606113, 12
          tz.transition 2043, 1, :o1, 29607205, 12
          tz.transition 2043, 10, :o2, 29610481, 12
          tz.transition 2044, 1, :o1, 29611657, 12
          tz.transition 2044, 10, :o2, 29614933, 12
          tz.transition 2045, 1, :o1, 29616025, 12
          tz.transition 2045, 10, :o2, 29619301, 12
          tz.transition 2046, 1, :o1, 29620393, 12
          tz.transition 2046, 10, :o2, 29623669, 12
          tz.transition 2047, 1, :o1, 29624761, 12
          tz.transition 2047, 10, :o2, 29628037, 12
          tz.transition 2048, 1, :o1, 29629129, 12
          tz.transition 2048, 10, :o2, 29632405, 12
          tz.transition 2049, 1, :o1, 29633581, 12
          tz.transition 2049, 10, :o2, 29636857, 12
          tz.transition 2050, 1, :o1, 29637949, 12
        end
      end
    end
  end
end
