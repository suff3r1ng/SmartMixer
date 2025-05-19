# TriNode SmartMixer: Multi-Controller IoT Stirring System with Sensor Fusion

## 1. Introduction

**Project Vision:** This document outlines a proposal for the "TriNode SmartMixer," a portable and intelligent device designed to automate the mixing or stirring of liquids within a container. The system leverages the Internet of Things (IoT) principles to provide enhanced control, monitoring, and data logging capabilities through a distributed architecture of multiple microcontrollers. The system's core functionality revolves around detecting the placement of a container onto a mixing station using three distinct ESP8266 microcontrollers each connected to a different sensor type. This multi-sensor approach provides redundancy and enhanced detection capabilities, which subsequently triggers the mixing motor. The TriNode SmartMixer is envisioned as a versatile tool suitable for hobbyists, small laboratories, educational settings, or even specific home-use scenarios requiring repetitive mixing tasks. It aims to offer both autonomous operation based on sensor fusion input and user-driven control through a dedicated mobile application.

**Key Features Overview:** The proposed system incorporates several key features derived from contemporary IoT practices and specific project requirements:

* **Automatic Activation:** The mixing station automatically initiates mixing upon the detection of a container, providing hands-free operation for routine tasks.
* **Mobile Application Control:** A Flutter-based mobile application provides a user-friendly interface for manual control of the mixing station, mode selection (automatic vs. manual), and system monitoring.
* **Cloud Backend Integration:** The system utilizes Supabase, an open-source backend-as-a-service platform, for robust user authentication, persistent data logging of mixing events, device status tracking, and potentially remote administration.
* **Portability:** The design prioritizes portability, implying considerations for battery power, compact form factor, and wireless connectivity.

**Target Use Cases:** The versatility of the TriNode SmartMixer lends itself to various applications:

* **Laboratory Assistance:** Assisting in the preparation of samples, reagents, or solutions where consistent, low-shear mixing is required, freeing up technician time.
* **Beverage Mixing:** Automating the stirring of beverages like protein shakes, powdered supplements, instant coffee, or even simple cocktails.
* **Hobbyist Applications:** Facilitating the mixing of paints, resins, or other craft materials requiring thorough blending before use.
* **Educational Tool:** Serving as a practical platform for teaching and demonstrating fundamental concepts in IoT, embedded systems programming, sensor integration, cloud connectivity, and mobile app development.

**Proposal Scope:** This proposal provides a comprehensive technical blueprint for the development of the TriNode SmartMixer system. It details the proposed system architecture, specifies hardware components and their integration, outlines the software design for the microcontroller firmware, cloud backend, and mobile application, describes the operational logic including control modes and data management strategies, and suggests potential avenues for future enhancements. It serves as a foundational document guiding the implementation process.

## 2. System Architecture Overview

### 2.1 Distributed Multi-Node System

The TriNode SmartMixer employs a distributed architecture consisting of three ESP8266 microcontrollers, each dedicated to a specific sensing or control function. This approach offers several advantages over a single-controller system:

1. **Enhanced Reliability:** The redundancy provided by multiple sensors and controllers ensures continued operation even if one sensor node fails.
2. **Specialized Functionality:** Each node can be optimized for its specific task without competing for processing resources.
3. **Flexible Placement:** The nodes can be positioned optimally for their respective sensing tasks.
4. **Scalability:** Additional sensor nodes can be added to the system in future iterations with minimal architectural changes.

The three ESP8266 nodes are configured as follows:

* **Coordinator Node (ESP8266 #1):** Houses the IR proximity sensor for container detection and controls the stirring motor. This node also manages WiFi connectivity to the Supabase backend and coordinates communication between all nodes.
* **Weight Sensor Node (ESP8266 #2):** Dedicated to the load cell/HX711 weight measurement system, providing precise container weight detection.
* **Touch Sensor Node (ESP8266 #3):** Implements capacitive touch sensing to detect container presence through physical contact.

### 2.2 Communications Architecture

The system implements a hybrid communications architecture:

1. **Local Inter-Node Communication:** The three ESP8266 nodes communicate with each other using ESP-NOW, a low-power protocol developed by Espressif that enables direct device-to-device communication without requiring a WiFi router. This provides low-latency, energy-efficient local messaging.

2. **Cloud Connectivity:** The Coordinator Node maintains a WiFi connection to the Supabase backend, handling all cloud communications for the system. This architecture minimizes power consumption by having only one node manage the relatively power-intensive WiFi operations.

### 2.3 Sensor Fusion Approach

A key innovative aspect of the TriNode SmartMixer is its sensor fusion strategy. The system combines data from three different sensor types to achieve robust container detection:

1. **IR Proximity Sensing:** Provides non-contact detection of the container's presence.
2. **Weight Measurement:** Offers precise detection and can determine if the container contains liquid.
3. **Capacitive Touch Detection:** Provides a fail-safe detection method that works regardless of container material.

The Coordinator Node implements a sensor fusion algorithm that prioritizes different sensors based on their reliability and availability. This results in more accurate container detection than any single sensor could provide alone.

### 2.4 Cloud Backend Services

The system utilizes Supabase as its backend-as-a-service platform, providing:

* **User Authentication:** Secure login and access control for the mobile application.
* **Real-time Database:** Storing device settings, status information, and usage logs.
* **RESTful API:** Enables the Coordinator Node and mobile application to interact with the cloud services.
* **Row-Level Security:** Ensures users can only access their authorized devices.

## 3. Hardware Components & Specifications

### 3.1 Microcontroller Selection

Three ESP8266 NodeMCU microcontrollers were selected as the foundation for the TriNode SmartMixer system due to their:

* **Integrated WiFi:** Built-in 802.11b/g/n capability for cloud connectivity.
* **ESP-NOW Support:** Native support for the low-power peer-to-peer protocol.
* **Sufficient I/O:** Each ESP8266 provides enough digital and analog I/O pins for their respective sensor interfaces.
* **Cost-Effectiveness:** Affordable price point that keeps the overall system cost reasonable.
* **Development Ecosystem:** Rich library support and community resources.

### 3.2 Sensor Components

#### 3.2.1 IR Proximity Sensor (Coordinator Node)
* **Sensor Type:** IR reflective sensor
* **Operating Range:** 2-30cm
* **Interface:** Digital output
* **Purpose:** Non-contact detection of container placement

#### 3.2.2 Weight Measurement System (Weight Sensor Node)
* **Sensor Type:** Load cell with HX711 amplifier
* **Measurement Range:** 0-10kg
* **Resolution:** 0.1g
* **Interface:** Digital (2-wire)
* **Purpose:** Precise weight measurement to detect container and contents

#### 3.2.3 Capacitive Touch Sensor (Touch Sensor Node)
* **Sensor Type:** Capacitive touch detection
* **Interface:** Digital output
* **Purpose:** Detect physical contact with the container or can be user input 

### 3.3 Motor Control System (Coordinator Node)

* **Motor Type:** DC motor with gearbox
* **Speed Control:** PWM 
* **Power Rating:** 12V, 1A max
* **Speed Range:** 0-100% in 1% increments

### 3.4 Power Subsystem

* **Main Power:** 12V DC adapter for motor supply
* **Logic Power:** 5V regulated supply for ESP8266 modules
* **Battery Option:** 18650 Li-ion cell

### 3.5 Physical Construction

* **Initial Prototype:** Breadboard construction for all electronic components to allow for rapid testing and iteration
* **Container Platform:** Simple acrylic or wood platform for container placement
* **Enclosure:** Off-the-shelf components and readily available materials (no 3D printing required)
* **Motor Coupling:** Magnetic coupling to allow for sealed operation with DIY adapter

## 4. Software Architecture

### 4.1 Firmware Design

#### 4.1.1 Coordinator Node Firmware
* **Core Responsibilities:**
  - IR sensor monitoring
  - Motor control via PWM
  - ESP-NOW communication coordination
  - WiFi and Supabase connectivity
  - Sensor fusion algorithm implementation
  - Mode management (auto/manual)
  - Timer functionality

* **Communication Protocols:**
  - ESP-NOW for inter-node communication
  - HTTP/HTTPS for Supabase REST API access
  - JSON for data serialization

#### 4.1.2 Weight Sensor Node Firmware
* **Core Responsibilities:**
  - Load cell reading and calibration
  - Weight measurement filtering
  - Container detection based on weight threshold
  - ESP-NOW communication with Coordinator

* **Communication Protocols:**
  - ESP-NOW for sending weight data to Coordinator
  - Two-wire interface for HX711 amplifier

#### 4.1.3 Touch Sensor Node Firmware
* **Core Responsibilities:**
  - Capacitive touch sensing
  - Debouncing and filtering
  - ESP-NOW communication with Coordinator

* **Communication Protocols:**
  - ESP-NOW for sending touch status to Coordinator

### 4.2 Inter-Node Communication Protocol

The system uses ESP-NOW for communication between nodes with a simple message structure:

* **Message Types:**
  - SENSOR_STATUS: Updates about sensor readings
  - COMMAND: Control instructions
  - HEARTBEAT: Regular connectivity check

* **Message Structure:**
  - Sender ID
  - Message type
  - Container detection status
  - Weight reading (if applicable)
  - Battery level
  - Command string (if applicable)

### 4.3 Cloud Integration

* **Supabase Integration Points:**
  - Device registration and status management
  - User account management and device assignment
  - Operation logging
  - Remote control command relaying

* **Data Models:**
  - Users: Authentication and profile information
  - Devices: Device registration and configuration
  - Device_Status: Real-time device state
  - Operation_Logs: Historical operation data

### 4.4 Mobile Application

* **Framework:** Flutter for cross-platform compatibility
* **Core Features:**
  - User authentication and profile management
  - Device discovery and connection
  - Real-time device status monitoring
  - Manual control of mixing speed and operation
  - Timer setting
  - Historical operation logs

* **UI Components:**
  - Login/registration screen
  - Device listing and selection
  - Device control dashboard
  - Settings configuration
  - Operation history and analytics

## 5. Operational Logic

### 5.1 Sensor Fusion Algorithm

The TriNode SmartMixer implements a hierarchical sensor fusion approach:

1. **Primary Detection:** Weight sensor data is prioritized if above threshold
2. **Secondary Detection:** If weight sensor is unavailable or below threshold, logical OR of IR and touch sensor data
3. **Fallback Detection:** If only one sensor is available, its data is used directly
4. **Confidence Scoring:** When multiple sensors are available, a confidence score is calculated based on agreement between sensors

### 5.2 Operating Modes

* **Automatic Mode:**
  - Mixing starts automatically when container is detected
  - Speed setting from application is applied
  - Timer functionality available for timed operation
  - Mixing stops when container is removed or timer expires

* **Manual Mode:**
  - Mixing is explicitly controlled from the application
  - Container detection still enforced as a safety feature
  - Speed adjustable in real-time
  - Timer functionality optional

### 5.3 Safety Features

* **Container Presence Requirement:** Motor operates only when container is detected
* **Timeout Safety:** Automatic shutdown after extended operation
* **Error Detection:** Monitoring of inconsistent sensor readings
* **Motor Current Monitoring:** Detection of mechanical blockage or overload

## 6. Implementation Roadmap

### 6.1 Development Phases

1. **Hardware Prototyping:**
   - Individual sensor node testing and calibration
   - Motor control circuit testing
   - Power management system implementation

2. **Firmware Development:**
   - Individual node firmware implementation
   - ESP-NOW communication testing
   - Sensor fusion algorithm development

3. **Cloud Backend Setup:**
   - Supabase instance configuration
   - Authentication system setup
   - Database schema implementation
   - API endpoint creation

4. **Mobile Application Development:**
   - UI/UX design
   - Flutter implementation
   - Supabase integration
   - Testing on Android and iOS

5. **Integration and Testing:**
   - Node integration testing
   - End-to-end system testing
   - User acceptance testing

### 6.2 Future Enhancement Opportunities

* **Additional Sensor Types:** Temperature sensors for monitoring liquid temperature
* **Advanced Mixing Patterns:** Programmable mixing sequences (e.g., pulse, variable speed)
* **Machine Learning:** Improved container detection using sensor data patterns
* **Recipe Storage:** Predefined mixing profiles for common tasks
* **Multi-Device Coordination:** Synchronize operations between multiple TriNode SmartMixers

## 7. Technical Challenges and Mitigations

### 7.1 Reliability Concerns

* **Challenge:** Ensuring reliable container detection across different materials and conditions
* **Mitigation:** Multi-sensor approach with sensor fusion and regular calibration routines

### 7.2 Power Management

* **Challenge:** Balancing performance with power consumption for portable operation
* **Mitigation:** Selective WiFi usage (only on coordinator node), deep sleep modes for sensor nodes

### 7.3 Connectivity

* **Challenge:** Maintaining reliable communication between nodes and cloud
* **Mitigation:** ESP-NOW for local resilience, offline operation capability when cloud unavailable

### 7.4 Security

* **Challenge:** Ensuring secure communication and preventing unauthorized access
* **Mitigation:** Leveraging Supabase security features, encryption for sensitive data

