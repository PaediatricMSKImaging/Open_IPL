# Open Access IPL Code

This repository contains various IPL scripts that have been developed and publish. The current available scripts and their associated publications include:

## Void Space Analysis:

Segments void spaces in bone microarchitecture from HR-pQCT images of the radius or tibia. This in the analysis is performed in mage Processing Language (IPL) and requires familiarity with OpenVMS and a license from Scanco Medical AG. Two versions of the code are available to perform the analysis on the first-generation (XCT1) and second-generation (XCT2) HR-pQCT systems. Outputs (e.g., void space volume fraction) are written to a log file where they can be exported and parsed.

***Code Files:***
- voidspace/IPL_VOIDSPACE_XT2.COM -> for use with first generation HR-pQCT scans
- voidspace/IPL_VOIDSPACE_XT1.COM -> for use with second generation HR-pQCT scans

***Manuscript:***
Whittier DE, Burt LA, Boyd SK. (2021) A new approach for quantifying localized bone loss by measuring void spaces. Bone. 2021 Feb;143:115785. doi: 10.1016/j.bone.2020.115785
