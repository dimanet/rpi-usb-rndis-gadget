# Raspberry Pi USB RNDIS Gadget

One-shot installer for a Raspberry Pi USB gadget network interface aimed at Windows hosts.

It configures:
- USB RNDIS gadget mode
- `usb0`
- fixed IP `10.99.99.1/24`
- no gateway
- no DNS
- Windows-friendly USB descriptors

## Install on a fresh Pi

```bash
curl -fsSL https://raw.githubusercontent.com/dimanet/rpi-usb-rndis-gadget/main/install-rpi-usb-rndis-gadget.sh | sudo bash && sudo reboot
```

Important:
- use the Pi's **data/OTG USB port**
- not the power-only port
- after reboot, reconnect the USB cable to make the host re-enumerate the gadget

## What it does

- enables `dtoverlay=dwc2`
- sets boot module loading to `modules-load=dwc2`
- installs a configfs-based RNDIS gadget service
- configures `usb0` as `10.99.99.1/24`
- uses a dedicated NetworkManager profile when NetworkManager is present
- otherwise falls back to direct `ip` configuration
- binds the gadget at boot with a systemd service

## Notes

This is intended for Pi models that support USB device/gadget mode, such as the Pi Zero 2 W.
