# ZoeStatus

This app is a replacement for the "official" Renault *Z.E Services* app on the iOS AppStore. 
However, it currently only covers a small part of its functionality:

- Battery state of charge (% and km)
- Charger state (e.g. speed)
- A/C preconditioning immediate and timed trigger, including result of last transmitted command

The goal is not really to eventually cover everything but to provide easier access to the most useful features in comparison to the official app.


It is based on the reverse engineered API documented here by Terence Eden: https://github.com/edent/Renault-Zoe-API

As long as there is no official API documentation, this app can never have more features than the offical website or app. It only attempts to make them a little more usable. For example, the current version of the offical app is asking for the credentials on almost every launch, which is rather annoying. With ZoeStatus, you only have to enter them once.

## Prerequisites:

- Renault "Zero Emission" vehicle, e.g. Renault ZOE
- Active "Renault ZE services" account (https://www.services.renault-ze.com)

## Compilation / Installation:

Use Xcode 11 or later to open and finally compile and install "ZoeStatus.xcodeproj" on your iOS 13 device.


## Usage:
At the first launch it should take you to the settings app, where you need to enter your Z.E. service credentials. 

<img src="./Screenshot_02.png" border="1" width="250">


They are only used to login into those services. Please check the source code files to verify that they are not transmitted anywhere else. This is why the source is published here. Another reason is that I doubt that I can successfully publish this app on the AppStore without providing the review team with credentials for testing (which, rather obviously, I cannot).

The user interface is rather primitive and currently all icon based because doing so saves me from providing a dozen translations:

<img src="./ZoeStatus-HowToUse.png" border="1" width="250"> <img src="./Screenshot_01.png" border="1" width="250"> <img src="./Screenshot_02.png" border="1" width="250"> <img src="./Screenshot_04.png" border="1" width="250">

The meaning of the symbols in order of appearance (left-to-right and top-down) on the app's main screen is as follows:

- battery state of charge in percent
- estimated remaining range in km
- date and time of transmission of status
- charger capability (slow, fast, or accelerated)
- charging (yes or no)
- estimated remaining time for charging
- plugged into charger (yes or no)
- A/C preconditioning command successful (yes or no)
- date and time of last transmission of A/C preconditioning command
- button for sending "A/C precondition now" (will turn into an adjustable countdown if successful)
- button for refreshing all of the above (long press will request an explicit state update)

## Data privacy:
The login credentials are stored locally on the iOS device as unencrypted user defaults (this may change in the future), which means that they are part of your ordinary device backup. Consequently, data security depends on your selected backup scheme (iCloud, local-unencrypted, local-encrypted).
The credentials are used to login to Renault's Z.E. services API (via encrypted https connection), but not sent to any other server. The data retrieved from Renault (e.g. the vehicle ID) is only processed inside the app, and sent back to Renault's API server again, but to no other server. It is only stord in RAM while the app is running.

## Disclaimer:

Neither me nor this work is in any way linked to Renault.

I may not be held responsible for any damage to your car or any inconveniences that you may run into as a result of using this app.

The app may stop working at any time (e.g. when there is a change of the Renault Z.E. API).

**Use at your own risk!**
