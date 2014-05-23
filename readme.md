This component provides an interface to control the Parrot [AR.Drone 2.0 Quadricopter](http://ardrone2.parrot.com/). It uses the Indy TidUDP component internally to send the UDP packets directly to the Quadricopter. You just need to connect your device to the AR.Drone provided access point and this component does the rest.

This currently only implements the basic movement controls for the Quadricopter. The methods are pretty straightforward to use. The values you can send are a single precision floating point number in the range from -1 to 1. 

Written with [Embarcadero Delphi XE6](http://www.embarcadero.com/products/delphi) in Object Pascal, but should also work with [C++Builder](http://www.embarcadero.com/products/cbuilder), [RAD Studio](http://www.embarcadero.com/products/rad-studio) or [Appmethod](http://www.appmethod.com) with a little effort.

Is designed to be cross platform and work in apps for Windows 32-bit, Windows 64-bit, OS X, Android and iOS.

**Note**: If you previously used the iOS controller app (or some other controller apps) then the Quadricopter may be paired to that device and you may need to reset it (the small recessed button in the battery compartment) before this component will work with the device.