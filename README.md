# TriNode SmartMixer

A distributed multi-controller IoT stirring system with sensor fusion capabilities, designed for automated liquid mixing.

## Overview

The TriNode SmartMixer is a portable and intelligent device that automates the mixing or stirring of liquids within a container. It uses three ESP8266 microcontrollers with different sensors to detect container placement and control the mixing motor. The system offers both autonomous operation based on sensor fusion and user-driven control through a dedicated mobile application.

## Features

- **Automatic Activation**: Mixing begins automatically when a container is detected
- **Mobile Application**: Control the mixer remotely using a Flutter-based app
- **Multi-Sensor Detection**: Uses IR proximity, weight (load cell), and capacitive touch sensing
- **Cloud Integration**: Connects to Supabase for user authentication and data logging
- **Variable Speed Control**: Adjust mixing speed from 0-100%

## Hardware Components

- 3× ESP8266 NodeMCU microcontrollers
- 1× 10kg Load Cell with HX711 amplifier
- 1× IR proximity sensor
- 1× Capacitive touch sensor
- 1× DC motor with gearbox
- 1× Motor driver (PWM capable)
- Power supply components
- Breadboard and jumper wires


### Serial Monitoring

You can monitor the operation of each node through the Arduino Serial Monitor (115200 baud). Each node provides diagnostic information about:

- Sensor readings
- Detection events
- Communication status
- Error conditions

## Project Structure

- `coordinator_node.cpp`: Firmware for the main controller node
- `weight_sensor_node.cpp`: Firmware for the weight sensor node
- `touch_sensor_node.cpp`: Firmware for the touch sensor node
- `/lib`: Flutter app source code
- `/database`: Supabase schema and migrations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments
- HX711 library contributors
- Flutter and Supabase teams for their excellent tools

---

*For more detailed information, see the [proposal document](proposal.md).*