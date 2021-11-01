import 'dart:convert';

import 'package:screenshots/src/utils.dart' as utils;
import 'package:test/test.dart';

void main() {
  test('issue #25: test parsing of iOS device info returned by xcrun', () {
    final expected = '''
    {
      "availability": "(available)",
      "state": "Shutdown",
      "isAvailable": true,
      "name": "iPhone X",
      "udid": "5A15DEB4-24BB-49F4-BD9A-FAF0B761FB27",
      "availabilityError": ""
    }
    ''';
    final deviceName = 'iPhone X';
    final deviceInfoRaw = '''
{
  "devices" : {
    "com.apple.CoreSimulator.SimRuntime.tvOS-12-0" : [
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple TV",
        "udid" : "9D1B003A-CD69-40C5-AF21-8768E908AC06",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple TV 4K",
        "udid" : "0043BA41-7C33-4DAE-8DA3-54631E87CA83",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple TV 4K (at 1080p)",
        "udid" : "0BD65D0D-A997-4593-97E2-A06028D0EA69",
        "availabilityError" : "runtime profile not found"
      }
    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-12-0" : [
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 5s",
        "udid" : "A5BF3110-7508-45CF-B9C4-67C5D7B841E9",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6",
        "udid" : "B9C7337F-B0DB-47F0-86FA-1E1F8E137C27",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6 Plus",
        "udid" : "5DCD4988-075A-4DDE-AE0C-C58151CDDB1F",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6s",
        "udid" : "205BD70B-0990-4F50-9705-8B86CEF98270",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6s Plus",
        "udid" : "406B467D-0C77-4CFD-AAE6-1BEFD2C43916",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 7",
        "udid" : "E733BF0F-EBC5-4114-9B00-AD9F5B18BC79",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 7 Plus",
        "udid" : "0BCA281E-D955-4204-B70E-800D45F73990",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 8",
        "udid" : "F5C26B8B-7C57-43F0-A27A-3E3A73BEBE2F",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 8 Plus",
        "udid" : "AB83DC08-9BE4-43A0-9FF3-BB60BE6D85F2",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone SE",
        "udid" : "DAE3948B-59F1-4E57-8269-9F652F5F0568",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone X",
        "udid" : "9FF60BB2-D95F-4CC9-9333-7F0B51572AF3",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone XS",
        "udid" : "B78E8710-379E-45AA-9250-51E2B8E9487E",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone XS Max",
        "udid" : "583D8436-F398-4A03-BBDF-4221209F50AA",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone XR",
        "udid" : "76C82D83-C43C-40DF-82C3-C30DFA5BB14E",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Air",
        "udid" : "2427054A-8DE2-4BBA-A805-6C32662BC2BC",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Air 2",
        "udid" : "FF4B1839-C058-4B27-8800-155EB79E4786",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad (5th generation)",
        "udid" : "761C8A07-C7B3-47F4-BEE7-C1C72E3F2D2E",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (9.7-inch)",
        "udid" : "2A34AA8A-1290-46CA-9D74-36E1637706AE",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (12.9-inch)",
        "udid" : "150AE743-F940-4D7C-9ED7-16D98733A779",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (12.9-inch) (2nd generation)",
        "udid" : "BD998D54-502E-4C09-880F-B7573CABC968",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (10.5-inch)",
        "udid" : "F181F6DF-3121-4F3C-9196-265EB1A4183D",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad (6th generation)",
        "udid" : "629D4076-D16E-4E75-B673-325428137C32",
        "availabilityError" : "runtime profile not found"
      }
    ],
    "com.apple.CoreSimulator.SimRuntime.tvOS-12-1" : [
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple TV",
        "udid" : "CED5D06C-87B8-43FE-9DBB-5FE805C67AD5",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple TV 4K",
        "udid" : "ADB00600-CEC5-46C3-BB6D-6F02494B06C1",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple TV 4K (at 1080p)",
        "udid" : "79E7D8E9-E7D8-4732-8121-9EBCEFFC3B2E",
        "availabilityError" : "runtime profile not found"
      }
    ],
    "com.apple.CoreSimulator.SimRuntime.watchOS-5-1" : [
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 2 - 38mm",
        "udid" : "D5220D28-5519-4D1B-89C4-25293E7B5043",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 2 - 42mm",
        "udid" : "3E0360D6-E2ED-4485-9F42-CF681707D54C",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 3 - 38mm",
        "udid" : "9509AF28-127A-4ADE-8C8A-897713AA0DEA",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 3 - 42mm",
        "udid" : "1C58420F-55B5-43A5-8BF9-AD6AC80C0EA8",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 4 - 40mm",
        "udid" : "851E4A5E-A123-4A6A-B4B3-E8CACAE36FDB",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 4 - 44mm",
        "udid" : "D9906A5C-60D6-4428-82C5-92385C425264",
        "availabilityError" : "runtime profile not found"
      }
    ],
    "com.apple.CoreSimulator.SimRuntime.tvOS-12-2" : [
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple TV",
        "udid" : "92F485FA-8DF6-4374-9E85-9917384B03E6",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple TV 4K",
        "udid" : "F7419627-0DAC-4EA8-AC64-AE0661F305CC",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple TV 4K (at 1080p)",
        "udid" : "1A4F140C-F963-41CE-9F75-6A013EF8F500",
        "availabilityError" : ""
      }
    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-12-2" : [
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 5s",
        "udid" : "60308A23-C457-4009-A5B2-0F939E48A3CE",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 6",
        "udid" : "6BE35F2F-3179-4628-9E9E-9F69C97FF489",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 6 Plus",
        "udid" : "F8B8BF5B-3200-474F-962A-22643A5A08DC",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 6s",
        "udid" : "AE3CAA24-EF4D-4AFB-B031-D3AF620A3320",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 6s Plus",
        "udid" : "E546FF74-0FB9-483E-83E9-977C6ED15676",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 7",
        "udid" : "87B5D775-BD14-4872-8247-CCDA551A30AD",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 7 Plus",
        "udid" : "D6EF53C2-0837-48AD-8D21-AF370E5C8F1B",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 8",
        "udid" : "5D599CB8-06EA-4DBD-BBA6-836CCDD6B9A0",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone 8 Plus",
        "udid" : "BA336C85-9FAD-4B9D-AB28-5AA92C60A321",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone SE",
        "udid" : "02802094-72CA-4F27-9214-0E0E9118F0C1",
        "availabilityError" : ""
      },
      $expected,
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone Xs",
        "udid" : "4A5710DC-E201-4F70-B158-0CAC29CD3D63",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone Xs Max",
        "udid" : "5E12C555-4BD8-42FD-9D7D-0951F6666A50",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone Xʀ",
        "udid" : "DA360D0B-419C-44B1-9540-9FA018F43FDB",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Air (3rd generation)",
        "udid" : "BC2FEA33-94C8-42C7-BAB2-F78D3F789FCC",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Air",
        "udid" : "AC9642EA-7771-4A04-9A26-A89359AD61A2",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Air 2",
        "udid" : "61BE65AB-13FB-4601-B835-8324C32DA490",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad (5th generation)",
        "udid" : "F0D8BD7C-1EE2-429F-B13A-00F3A1E65DC6",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Pro (9.7-inch)",
        "udid" : "C6AF1993-8F11-47A4-982E-1D3EE3B40F1A",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Pro (12.9-inch)",
        "udid" : "4B129654-E7DA-4E6F-8EC4-A2F78439E62F",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Pro (12.9-inch) (2nd generation)",
        "udid" : "9F65AD33-8892-47A4-9304-CF50FF381105",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Pro (10.5-inch)",
        "udid" : "F9126779-36AF-4D15-B446-586CFAC0B48F",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad (6th generation)",
        "udid" : "7DD7BDBF-A3CF-4B2E-BA29-20FA5BBEC90C",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Pro (11-inch)",
        "udid" : "6BD4B0E7-0784-47B6-86A3-61FCD4906D00",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPad Pro (12.9-inch) (3rd generation)",
        "udid" : "D7DC3394-69C1-48C5-A75F-A5B1D6DF6697",
        "availabilityError" : ""
      }
    ],
    "com.apple.CoreSimulator.SimRuntime.watchOS-5-2" : [
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple Watch Series 2 - 38mm",
        "udid" : "FE8BFB1B-ED17-4617-9966-59BFB7C73FF2",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple Watch Series 2 - 42mm",
        "udid" : "671A4759-45DB-43F6-8C14-8F4A69C660CB",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple Watch Series 3 - 38mm",
        "udid" : "87F4D925-F57D-45E3-979F-A904F50117AC",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple Watch Series 3 - 42mm",
        "udid" : "758E90C0-F2D3-4BBB-A991-AD3A395131E2",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple Watch Series 4 - 40mm",
        "udid" : "047A0CE3-80F0-47CC-A595-ACE74AABD49B",
        "availabilityError" : ""
      },
      {
        "availability" : "(available)",
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "Apple Watch Series 4 - 44mm",
        "udid" : "B7F80E7C-CE90-4D8D-9FD8-A53A1EACF866",
        "availabilityError" : ""
      }
    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-12-1" : [
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 5s",
        "udid" : "B6883FB9-ECA7-422F-9C60-B7C9081DAACA",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6",
        "udid" : "57D77D5D-4A35-4202-A7CC-B535A9BA8AD0",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6 Plus",
        "udid" : "CB1A203A-7ADC-4A9D-B1BE-BDDE09002C89",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6s",
        "udid" : "27BE3DB3-7A9A-4CBB-AE8B-42E1FDE1B914",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6s Plus",
        "udid" : "7118AE1E-8286-441C-931C-852197C03854",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 7",
        "udid" : "585ED7CD-2E00-4775-AEE0-1E855C180000",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 7 Plus",
        "udid" : "1DDEB379-DB7F-42AE-B27E-BCFB50558D77",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 8",
        "udid" : "5C4D812F-08CF-4E58-A6B0-3D660821A979",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 8 Plus",
        "udid" : "39CC994D-2D36-4ECD-A3D6-012132C331A6",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone SE",
        "udid" : "639A50D1-2004-42E5-A566-A0B37044D21E",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone X",
        "udid" : "AF4C1867-5147-4003-847A-20F605F1CE77",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone XS",
        "udid" : "4E674A91-6330-4436-B6CC-0D08A671506F",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone XS Max",
        "udid" : "000A067C-FACB-434E-A0E0-1E5DEEB5EC8E",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone XR",
        "udid" : "01668E55-3AEE-4D2D-AE53-24A40A2F286E",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Air",
        "udid" : "9DBEC1EE-17F2-4F55-AF7E-15D5AC38E28D",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Air 2",
        "udid" : "7B97A6AA-6700-435A-9CB6-884287ECA7BF",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad (5th generation)",
        "udid" : "AB634A6A-1B5A-457B-A38E-A6E0180DBD9A",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (9.7-inch)",
        "udid" : "7C15A980-8B52-46D7-8F36-F5CC511AF275",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (12.9-inch)",
        "udid" : "CACD622A-87A8-4C24-94A3-F0156FC6DBF0",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (12.9-inch) (2nd generation)",
        "udid" : "31FFDFFA-43C5-455D-BDCB-A0CB082F4EEF",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (10.5-inch)",
        "udid" : "F4414DA7-8C54-4569-9956-6F1A9F8F7D1A",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad (6th generation)",
        "udid" : "FA5FD44F-687F-4D5D-A810-F68960F135F3",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (11-inch)",
        "udid" : "9F4CD605-EE11-4A3C-88F4-7A5E798913FA",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPad Pro (12.9-inch) (3rd generation)",
        "udid" : "77E8A130-612D-4C2A-892F-4A70D8D16B2D",
        "availabilityError" : "runtime profile not found"
      }
    ],
    "com.apple.CoreSimulator.SimRuntime.watchOS-5-0" : [
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 2 - 38mm",
        "udid" : "5B6CB879-6EFD-427E-82D1-BF9B362CC8A2",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 2 - 42mm",
        "udid" : "842286D8-8756-4AFC-A56B-BB4EDFFEDCF1",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 3 - 38mm",
        "udid" : "80AE2C15-AA62-4DE5-A036-BD00033B81A9",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 3 - 42mm",
        "udid" : "98460128-5E04-49A2-ABDC-4D7BD27FA0DC",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 4 - 40mm",
        "udid" : "891D4AD4-9FD0-49B6-9579-55AE64088C6E",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "Apple Watch Series 4 - 44mm",
        "udid" : "E83E5537-61EB-42F1-91A2-B5A30D00598D",
        "availabilityError" : "runtime profile not found"
      }
    ]
  }
}
''';
    print(
        'getIosDevice=${utils.getHighestIosSimulator(utils.getIosSimulators(), deviceName)}');
    final deviceInfo = jsonDecode(deviceInfoRaw)['devices'];
    final iosDevices = utils.transformIosSimulators(deviceInfo);
//    final iosDevice = getHighestIosDevice(iosDevices, deviceName);
//    expect(
//        () => getHighestIosDevice(iosDevices, deviceName), throwsA(anything));
    expect(utils.getHighestIosSimulator(iosDevices, deviceName),
        jsonDecode(expected));
  }, skip:     true  );

  test('issue #73: parse without availability', () {
    final expected = '''
      {
        "state" : "Shutdown",
        "isAvailable" : true,
        "name" : "iPhone Xs Max",
        "udid" : "3AD11D72-B3FA-4E4C-94B3-E4E51C67250A"
      }
    ''';
    final deviceName = 'iPhone Xs Max';
    final deviceInfoRaw = '''
{
  "devices" : {
    "com.apple.CoreSimulator.SimRuntime.iOS-12-0" : [

    ],
    "com.apple.CoreSimulator.SimRuntime.tvOS-12-2" : [

    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-12-2" : [
      $expected
    ],
    "com.apple.CoreSimulator.SimRuntime.watchOS-5-2" : [

    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-9-3" : [

    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-12-1" : [

    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-9-0" : [

    ]
  }
}    
    ''';
    final deviceInfo = jsonDecode(deviceInfoRaw)['devices'];
    final iosDevices = utils.transformIosSimulators(deviceInfo);
    expect(utils.getHighestIosSimulator(iosDevices, deviceName),
        jsonDecode(expected));
  });
}
