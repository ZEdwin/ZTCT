ZTCT
====

ZTCT - SAP ABAP Transport Checking Tool (Object Level)

Transport Checking Tool: Analyze transports before moving them to production. Determine the proper order and highlight risks.

NOTE: This README is just a very short summary. For a more detailed explanation, please check out the Blog on SCN or the manual included here on GitHub.

BLOG: http://scn.sap.com/community/abap/blog/2013/05/31/transport-checking-tool-object-level

INTRODUCTION

Why this tool

Transporting a project to Production gets more complicated with increasing numbers of developers and transports. With the final Go-Live date in sight, it is vital to have a correct list of transports that can be moved with minimal risk.

Short Description

This tool checks if transports can be moved from one environment they have been transported to (usually this will be Test or Acceptance) to the next environment. The check is performed on object level. All objects in the selected transports are checked.

Checks

Are there newer version in production that will be overwritten? Are there older versions existing in Acceptance that are not included in your list? Are there objects that use DDIC objects that are not existing in Production and are not included in your list? And more...

Other options

It is possible to save your list so you can continue the check later. You can merge lists, add single transports, add transports that contain conflicting objects or delete rows. Each time objects are added or removed, the same objects that remain in the list are checked again to ensure that the list stays up to date.

Limitations

This tool was initially developed for use in a 3-Tier system (DEV-->QAS-->PRD), to check if transports can safely be moved to Production. However, it can also be used to check if transports can be moved to other environments.
For example: If the company uses a 4-tier system (DEV-->TST-->QAS-->PRD), a check can be done on the route DEV-->TST-->QAS, DEV-->QAS-->PRD or DEV-->TST-->PRD.
