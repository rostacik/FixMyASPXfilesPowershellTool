Fix my .ASPX files with Powershell Tool
============================

Why
-
There was need in our organization for fixing many older WebForms aspx files and tweaking them little bit in direction to html5 practices, speeding them up, fixing some javascript errors, etc.

What it does
-
Currently these things :


- Replacing head tag,
- Removing XML namespace from HTML tag,
- Dropping properties from body start tag,
- Removing head tag with vs_targetSchema from older VS,
- Moving script references to the bottom of a file (before end of body tag),
- Scanning inline JavaScript (should be removed to separate .js file, I know) and fixing calling IDs without document.getElementById - older IE behavior,
- Deleting row with old http-equiv=MSThemeCompatible,
- Remove language="javascript" from script tag



What you need to make it run
-
- VS 2012 Premium update 3 (I use this one, Ultimate and any other with possibility to install plugin should be also fine)
- Plugin to work with PowerShell in VS - PowerShell Tools for Visual Studio - [http://visualstudiogallery.msdn.microsoft.com/c9eb3ba8-0c59-4944-9a62-6eee37294597](http://visualstudiogallery.msdn.microsoft.com/c9eb3ba8-0c59-4944-9a62-6eee37294597 "PowerShell Tools for Visual Studio")
- PowerShell v3

(side note - you could also use PowerShell ISE for development) 

Usage
-
Basically there are 3 possibilities :

- No parameters = run it against ps file working dir, scan for all files, process them,
- Specify folder parameter = go to given dir, find all .aspx, process them,
- Specify file name, process it

You can also use -Verbose switch to make script display more info about what it is doing.

Sample of the output
-
![sample output](https://skydrive.live.com/embed?cid=78A5783DE37D2EBE&resid=78A5783DE37D2EBE%217190&authkey=AHQoJ8HgHySFPII)

Pull requests are more than welcome. Enjoy this small script.