# Novation-Mini-MK1-LED-Ligthshow
Simple background powershell script to animate LEDs of Novation Launchpad Mini Mk1 usb controllor over Midi commands whilst it's hooked upto a Windows PC and not in use. The actuation on this pad isn't great and I actually wouldn't recommend it for live music shows when you need to guarantee registration of button presses, so relegates it's only use as a light panel.

The Novation mini MK1 does come with a default standby animation when it's powered, but as soon as the USB data lines are activated which occurs as soon as Windows boots due to built-in midi drivers and midi API, the built-in lightshow disables itself waiting for midi output from the PC. Novation's apparent only documented solution for creating lightshows on the launchpad is to use Ableton to play midi notes through the device, so this is a built-in Windows alternative requiring no additional software/drivers.

The buttons have 7 states of colour - Blank, Green, Dim Green, Orange, Dim Orange, Red & Dim Red. It has an 8x8 grid of reactive buttons, alongside an additional 8 buttons in a row along the top and an additional 8 buttons in a column along the left.

Powershell script does currently have 4 sequences built-in across the 8x8 grid it switches between every 18 seconds, a diagonal transitional wave wipe, an expanding diamond wipe, a random sparkle effect and a trial chase.

The additional row and column lights on the edge are just set to move a set of colours along.

Launching the .bat script to run the .PS1 script in a bypassed environment, this can be launched manually or as a startup task in task schedular/startup apps using SYSTEM user.

When the controller is required, the powershell script will need stopping, by either stopping the service or simply unplugging and plugging the USB controller back in.

The work-in progress on this controller, is to make the 8x8 matrix more easily user programable of individual lights to create user shapes and patterns as part of the sequence. To revise the current sequences as not the best of animations. Updating the status of lights is slow/laggy, as apparently there is a data limit of transmitting data over Midi, to look further into true data transfer rate for smoother animations.
