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

**High-Level Conceptual Diagram:** The system architecture comprises several interconnected modules. At the core is a Sensor-Motor Unit managed by three distinct ESP8266 microcontrollers. These microcontrollers must communicate amongst themselves, possibly using a protocol like ESP-NOW for direct peer-to-peer messaging or a MQTT brokered either locally or via the cloud. At least one ESP8266 (or potentially all three) utilizes its built-in Wi-Fi capabilities to connect to a local Wi-Fi network, granting access to the internet via a standard router. This internet connection enables communication with the Supabase cloud backend, which handles authentication (Auth), data storage (Database), and realtime data synchronization (Realtime). A Flutter mobile application interacts with Supabase for user login, data display, and sending control commands. Optionally, for reduced latency in manual control, the Flutter app might communicate directly with the ESP8266 devices over the local Wi-Fi network. An administrative interface, potentially leveraging Supabase's built-in tools, allows for higher-level system management.

**Data Flow Description:** The primary data flows within the system are as follows:

1.  **Sensor to Motor:** Sensor detects a container -> ESP8266 reads sensor state -> ESP8266 activates the corresponding motor.
2.  **Status Reporting:** Sensor state changes or motor activation/deactivation -> ESP8266 -> Supabase Database (updating device/station status).
3.  **Realtime Display:** Supabase Database updates -> Supabase Realtime -> Flutter App (displaying current status).
4.  **Cloud-based Manual Control:** User action in Flutter App -> Supabase Database (writing command) -> ESP8266 (polling Supabase or receiving push via persistent connection) -> Motor Activation/Deactivation.
5.  **Local Manual Control (Optional):** User action in Flutter App -> Direct local network message (HTTP/UDP) -> ESP8266 -> Motor Activation/Deactivation.
6.  **User Authentication:** User credentials are entered in the Flutter App -> Supabase Auth -> Authentication Token/Session established.
7.  **Data Logging:** Mixing event completion (start/end times, duration) -> ESP8266 -> Supabase Database (mix\_logs table).
8.  **Admin Actions:** Admin interaction via Supabase Panel -> Supabase Database -> Potential command propagation to ESP8266 (similar to manual control).

**Technology Stack Summary:** The core technologies underpinning this project, as specified, are:

* **Microcontrollers:** 3x ESP8266 modules.
* **Backend:** Supabase (PostgreSQL DB, Auth, Realtime).
* **Mobile Frontend:** Flutter framework.

**Architectural Considerations with Multiple ESP8266s:** The requirement to use three distinct ESP8266 microcontrollers, each connected to a different sensor type, introduces architectural choices and complexities compared to utilizing a single microcontroller with sufficient I/O capabilities (like an ESP32). While a single ESP32 could likely manage multiple sensors and motors directly, simplifying firmware and hardware, the three-ESP8266 approach necessitates an explicit inter-device communication strategy. Options include ESP-NOW, a proprietary peer-to-peer protocol from Espressif, or a standard protocol like MQTT, which may require a message broker. This inter-device link adds latency, potential points of failure (message loss), and complexity to the firmware design for handling communication protocols and data synchronization between the units. Furthermore, managing firmware updates across three separate devices can be more cumbersome than updating a single device. Power management also becomes more complex, as coordinating sleep and wake cycles across multiple interacting wireless devices requires careful planning to maximize battery life if portability is a key goal. The potential benefits of this distributed approach might include physical separation flexibility if the mixing station is not co-located, or dedicated processing resources per sensor, although the latter is unlikely to be a limiting factor for this application's typical workload. The design must therefore carefully select and implement the inter-ESP communication method, acknowledging the trade-offs involved, and account for potential synchronization challenges inherent in a distributed microcontroller system.

## 3. Hardware Design and Implementation

### 3.1 Microcontroller Sub-system (3x ESP8266)

**Module Selection:** For ease of prototyping and development, readily available development boards based on the ESP8266, such as the NodeMCU V2/V3 or Wemos D1 Mini (typically using the ESP-12E/F module), are recommended. These boards integrate the ESP8266 chip with essential components like USB-to-serial converters, voltage regulators, and breakout pins. Key advantages include low cost, extensive community support and documentation, and integrated Wi-Fi connectivity. The ESP8266 provides sufficient GPIO pins for interfacing with a sensor and a motor driver per unit.

**Role Allocation:** The most straightforward allocation assigns one ESP8266 to manage each sensor independently. Each ESP8266 would be responsible for reading its associated sensor, controlling the motor via a driver, and communicating its status to the backend. Coordination, if necessary (e.g., for power management or global mode switching), would require inter-device communication. One ESP could potentially be designated as a coordinator, handling all external Wi-Fi communication with Supabase and relaying commands/data to the other two via a local protocol, or they could operate in a peer-to-peer fashion.

**Inter-Device Communication:** Given the multi-ESP8266 architecture, a method for local communication is essential if coordination is needed.

* **Option 1: ESP-NOW:** This Espressif-specific protocol allows direct, connectionless communication between ESP devices without requiring connection to a Wi-Fi access point. It offers low latency and reduced overhead compared to TCP/IP-based protocols, making it suitable for rapid local status updates or command relaying. However, its range is limited, and managing pairwise communication or broadcasts requires careful firmware implementation.
* **Option 2: MQTT:** Message Queuing Telemetry Transport (MQTT) is a standard publish/subscribe messaging protocol well-suited for IoT applications. Using MQTT would require a broker: either a cloud-based one (potentially integrated with Supabase or a separate service), or a local one (which could run on one of the ESP8266s if powerful enough, or a dedicated device like a Raspberry Pi). MQTT offers flexibility in network topology and simplifies communication logic through its pub/sub model but introduces higher overhead and dependency on the broker compared to ESP-NOW.

**Recommendation:** For inter-device coordination focused on low latency and simplicity between the ESPs (e.g., sharing basic status or simple commands), ESP-NOW presents a compelling option. Standard Wi-Fi connectivity would still be used by at least one ESP (or all, depending on the chosen topology) for communication with the Supabase cloud backend. If all devices require independent, direct access to the cloud backend, or if a more standardized and flexible messaging system is preferred despite the overhead, using MQTT (potentially via a Supabase MQTT bridge if available and suitable, or a separate broker) for both inter-device and cloud communication might streamline the software architecture. The choice depends on the specific coordination requirements and tolerance for complexity versus overhead.

### 3.2 Sensor Integration

**Sensor Type Selection:** Several sensor types can detect the presence of a container:

* **Load Cells/Weight Sensors:** These measure force/weight.
    * **Pros:** Can detect the presence of a container and potentially estimate the volume of contents if calibrated.
    * **Cons:** Require careful mounting, sensitive to vibrations, need amplification and ADC conversion (e.g., using an HX711 module), potentially higher cost and complexity.
* **IR Proximity Sensors (Reflective):** These emit infrared light and detect its reflection off an object.
    * **Pros:** Simple, low cost, non-contact detection.
    * **Cons:** Performance can be affected by ambient light, container material/color/reflectivity, and requires placement within a specific detection range.
* **Capacitive Proximity Sensors:** These detect changes in capacitance caused by a nearby object (including liquids or containers).
    * **Pros:** Can detect through thin non-metallic walls.
    * **Cons:** Sensitivity may require tuning, susceptible to environmental factors and electrical noise.
* **Mechanical Limit Switches:** Simple switches activated by physical contact.
    * **Pros:** Very reliable detection, simple interface.
    * **Cons:** Requires physical contact which might be undesirable, potential for wear over time, less aesthetically integrated.

**Recommendation:** For a balance of simplicity, cost-effectiveness, and non-contact operation suitable for a prototype, IR proximity sensors are recommended. A digital output version can be directly connected to an ESP8266 GPIO pin configured as a digital input. The detection threshold might need minor physical adjustment depending on the typical containers used. Alternatively, if weight detection or volume estimation is desired, load cells with an HX711 interface module offer more advanced capabilities at the cost of increased complexity.

### 3.3 Mixing Mechanism

**Motor Selection:** The choice of motor affects mixing power, control precision, and cost:

* **Small DC Motors (e.g., 3-6V hobby motors):**
    * **Pros:** Very low cost, widely available.
    * **Cons:** Speed control requires Pulse Width Modulation (PWM), may lack sufficient torque for thicker liquids without gearing.
* **Small Geared DC Motors:**
    * **Pros:** Provide significantly higher torque at lower, more suitable mixing speeds due to integrated gearboxes.
    * **Cons:** Typically larger, potentially noisier, slightly higher cost than basic DC motors.
* **Small Stepper Motors (e.g., 28BYJ-48 with driver board):**
    * **Pros:** Allow for precise control over rotation angle and speed.
    * **Cons:** Require more complex driving sequences and dedicated driver boards (like ULN2003), generally slower maximum speed, torque might be limited unless geared.

**Motor Driver:** ESP8266 GPIO pins cannot directly provide the current or voltage required by most motors. A dedicated motor driver IC is essential. Common options include the L293D or L298N H-bridge drivers for DC motors, allowing control over speed (via PWM) and direction. For stepper motors like the 28BYJ-48, a ULN2003 Darlington array driver is typically used. More efficient H-bridge drivers like the TB6612FNG are also available, offering better performance especially for battery-powered applications. The ESP8266 controls the motor driver using several GPIO pins (e.g., enable pin, direction pins, PWM pin for speed).

**Mixing Implement:** The physical stirring mechanism attached to the motor shaft could be a small 3D-printed propeller or paddle. Alternatively, for applications where contamination is a concern or cleaning is difficult, a magnetic stirrer setup could be employed (motor spins a magnet below the station, which couples with a magnetic stir bar placed inside the container).

**Recommendation:** For a good balance of torque suitable for common liquids, relative simplicity of control, and reasonable cost, small geared DC motors are recommended. Pairing these with an efficient H-bridge motor driver like the TB6612FNG (preferred over L293D/L298N for better power efficiency) is advisable, particularly given the portability requirement.

### 3.4 Portability & Power System

**Power Source:** Portability necessitates a self-contained power source:

* **Li-ion/LiPo Batteries:** Offer high energy density and rechargeability, making them ideal for portable electronics.
    * **Cons:** Require dedicated charging circuitry (e.g., based on TP4056) and protection circuits (PCM) to prevent overcharge, over-discharge, and short circuits. Multiple cells might be needed in series or parallel to meet voltage and capacity requirements.
* **USB Power Bank:** A convenient off-the-shelf solution providing regulated 5V output.
    * **Cons:** The device remains tethered unless the power bank is integrated into the enclosure. Peak current delivery might be insufficient if all motors start simultaneously.
* **AA/AAA Batteries:** Easily replaceable but offer lower energy density compared to Li-ion. Alkaline cells are not rechargeable, while NiMH rechargeable variants have lower voltage per cell. Achieving sufficient voltage and capacity might require a large number of cells.

**Voltage Regulation:** If using batteries with a nominal voltage higher than required by the components (e.g., a 7.4V LiPo pack), step-down voltage regulators will be needed to provide stable 5V (for some drivers/motors) and 3.3V (for ESP8266 modules and potentially sensors). Efficient switching regulators (buck converters) are preferable to linear regulators for battery-powered applications due to lower energy loss as heat.

**Power Management:** Aggressive power management is crucial for achieving reasonable battery life. The ESP8266 supports various sleep modes, including deep sleep where most of the chip is powered down, consuming only microamperes. The firmware must be designed to utilize deep sleep whenever the device is idle, waking up periodically via a timer (to check for cloud commands or send heartbeats) or instantly via an external trigger (e.g., a change on the sensor GPIO pin indicating container placement/removal). Implementing and coordinating sleep across three interconnected ESP8266s adds significant complexity.

**Enclosure Design:** A compact and stable enclosure is needed to house the ESP8266 boards, batteries, power circuitry, sensors, and motor assemblies. It should provide stable platforms for placing containers above the sensors/motors. 3D printing (using materials like PLA or ABS) offers flexibility in creating a custom-fit, integrated design.

**Power Consumption Considerations:** The combination of three ESP8266 modules, motors, and associated sensors presents a significant power challenge for a portable, battery-operated device. Each ESP8266 consumes minimal power in deep sleep but draws considerable current (tens to hundreds of milliamperes) when the CPU is active, and especially when the Wi-Fi radio is transmitting. Motors, particularly DC motors, can draw substantial current, especially during startup or under load. Even sensors contribute a small quiescent current draw. The cumulative power demand necessitates a battery with significant capacity (measured in mAh) to achieve acceptable operating times between charges. Implementing deep sleep modes is therefore not just an option but a necessity. However, deep sleep introduces latency, as the device takes time to wake up, reconnect to Wi-Fi (if needed), and respond. Furthermore, the desire for realtime status updates and responsiveness to manual commands from the cloud conflicts directly with long sleep durations. Frequent wake-ups to poll for commands or push status updates drastically reduce battery life. This creates a fundamental trade-off: enhanced responsiveness and realtime features come at the cost of shorter battery life, while longer battery life implies greater latency. The design must carefully balance these factors, potentially requiring larger, heavier batteries, which could impact the practicality of the "portable" aspect. A detailed power budget analysis during the design phase is highly recommended. Selecting energy-efficient components, like the TB6612FNG motor driver over the L298N, becomes critical.

### Table 1: Key Component Selection Summary

| Component                 | Selected Option/Model                     | Rationale/Key Considerations                                                      |
| :------------------------ | :---------------------------------------- | :-------------------------------------------------------------------------------- |
| Microcontroller           | ESP8266 (NodeMCU/Wemos D1 Mini)           | Low cost, integrated Wi-Fi, sufficient GPIO, large community support.             |
| Sensor Type               | IR Proximity Sensor (Digital Output)      | Non-contact, low cost, simple interface, suitable for container presence detection. |
| Motor Type                | Small Geared DC Motor (3-6V range)        | Good torque at low speeds, suitable for mixing liquids, relatively low cost.        |
| Motor Driver              | TB6612FNG H-Bridge Driver                 | More power-efficient than L293D/L298N, suitable for battery power, controls speed/direction. |
| Power Source Option       | Li-ion/LiPo Battery Pack + Protection/Charger | High energy density, rechargeable, suitable for portability. Requires safety circuits. |
| Inter-ESP Communication   | ESP-NOW (Recommended for local coord.)    | Low latency, low overhead for direct ESP-to-ESP communication. Wi-Fi for cloud.   |

## 4. Supabase Backend Services

**4.1 Platform Overview:** Supabase is chosen as the backend platform, offering an open-source alternative to Firebase with a suite of tools well-suited for IoT projects. Key features leveraged in this project include:

* **PostgreSQL Database:** A robust, relational database for storing structured data like user information, device details, station status, and mixing logs.
* **Authentication:** Built-in user management system for handling user registration, login, and session management securely.
* **Realtime Subscriptions:** Allows clients (like the Flutter app) to subscribe to database changes and receive updates in realtime, enabling live monitoring.
* **Storage (Optional):** Could be used for storing firmware updates or larger configuration files if needed.
* **Edge Functions (Optional):** Serverless functions for running custom backend logic (e.g., data validation, notifications).

### 4.2 Data Modeling (Supabase DB)

**Schema Design:** A relational database schema is proposed to organize the system's data effectively within Supabase PostgreSQL:

* **users:** Managed by Supabase Auth, contains user identity information (ID, email, etc.).
* **devices:** Represents each physical TriNode SmartMixer unit.
    * `device_id` (UUID, Primary Key): Unique identifier for the device.
    * `user_id` (UUID, Foreign Key -> users.id): Links the device to its owner.
    * `name` (TEXT): User-assignable name for the device (e.g., "Lab Mixer 1").
    * `status` (TEXT, e.g., 'online', 'offline'): Current connectivity status.
    * `operating_mode` (TEXT, e.g., 'auto', 'manual'): Current global mode set by the user.
    * `last_heartbeat` (TIMESTAMPTZ): Timestamp of the last communication received from the device.
* **mixing\_stations:** Represents the individual stations within a device.
    * `station_id` (UUID, Primary Key): Unique identifier for the station.
    * `device_id` (UUID, Foreign Key -> devices.device\_id): Links the station to its parent device.
    * `station_index` (INTEGER, 1, 2, or 3): Identifies the station within the device.
    * `motor_status` (TEXT, e.g., 'idle', 'running'): Current state of the motor.
    * `sensor_status` (TEXT, e.g., 'container\_present', 'empty'): Current state reported by the sensor.
    * `pending_command` (TEXT, e.g., 'start', 'stop', NULL): Used for cloud-to-device command queue if polling is used.
    * `last_updated` (TIMESTAMPTZ): Timestamp of the last status update for this station.
* **mix\_logs:** Records historical mixing events.
    * `log_id` (UUID, Primary Key): Unique identifier for the log entry.
    * `station_id` (UUID, Foreign Key -> mixing\_stations.station\_id): Identifies which station performed the mix.
    * `user_id` (UUID, Foreign Key -> users.id): Identifies the user associated with the device at the time.
    * `start_time` (TIMESTAMPTZ): Timestamp when mixing started.
    * `end_time` (TIMESTAMPTZ): Timestamp when mixing stopped.
    * `duration_ms` (INTEGER): Calculated duration of the mix in milliseconds.
    * `trigger_mode` (TEXT, 'auto' or 'manual'): Indicates how the mixing was initiated.

**Rationale:** This schema structure effectively links users to their devices, allows independent tracking and control of each mixing station, facilitates realtime status updates, and provides a historical record of operations for analysis or review. The inclusion of `operating_mode` in `devices` and `pending_command` in `mixing_stations` directly supports the required control logic.

### 4.3 Authentication & User Management

**Implementation:** Supabase Auth will be utilized to handle user accounts. The Flutter application will implement screens for user registration (e.g., email/password signup), login, and potentially password recovery flows using the Supabase client SDK. Upon successful authentication, the application receives a user ID and session token, which are used to authorize subsequent requests to the database (via Row Level Security policies) and associate devices and logs with the correct user.

### 4.4 Realtime Capabilities

**Mechanism:** Supabase's Realtime engine will be employed primarily for pushing status updates from the backend to the Flutter application. The app will subscribe to changes in the `mixing_stations` table, filtered by the `device_id` of the device currently being viewed by the logged-in user. When an ESP8266 updates the status of a station (e.g., `motor_status` changes to 'running', `sensor_status` changes to 'container\_present') in the Supabase database, the Realtime service automatically pushes this change to all subscribed clients (the Flutter app), enabling a live view of the device state.

**Device-to-Cloud Communication:** The ESP8266 firmware will be responsible for sending updates to the Supabase backend. This can be achieved by making secure HTTP POST or PATCH requests to the Supabase REST API (using the device's unique ID and potentially an API key or JWT for authentication) to update rows in the `devices` and `mixing_stations` tables whenever a relevant event occurs (e.g., sensor change, motor start/stop, periodic heartbeat). Alternatively, if an MQTT bridge is configured, the ESP8266 could publish status updates to specific MQTT topics mapped to the database.

**Cloud-to-Device Communication (Commands):** Delivering commands (e.g., manual start/stop) from the cloud (initiated by the app) to the ESP8266 presents a challenge, especially for battery-powered devices aiming to use deep sleep.

* **Polling:** The ESP8266 can periodically wake up from sleep, connect to Wi-Fi, and make an HTTP GET request to Supabase to check the `pending_command` field in its corresponding `mixing_stations` row. If a command is present, the ESP executes it and clears the field. This method is power-efficient during idle periods but introduces latency equal to the polling interval.
* **Persistent Connection:** Maintaining a persistent connection (e.g., via MQTT subscription or a Supabase Realtime client library on the ESP, if available and stable) allows the backend to push commands to the device almost instantly. However, keeping Wi-Fi and the connection active significantly increases power consumption, potentially making battery operation impractical.

### 4.5 Admin Panel Functionality

**Implementation:** Supabase provides a built-in web-based interface for Browse and managing database tables, which can serve as a basic admin panel. Administrators can log in to the Supabase project dashboard to view users, devices, station statuses, and logs. For more tailored administrative features, a simple custom web application could be built using frameworks like React or Vue, interacting with Supabase via its JavaScript client library.

**Features:** Potential administrative functions include: viewing all registered users and their associated devices, monitoring the realtime status and heartbeat of all devices, inspecting detailed mixing logs across all users, potentially disabling or deleting devices or users, and manually triggering actions on specific stations for debugging or testing purposes.

**Realtime Synchronization and Command Latency:** Achieving seamless, low-latency interaction between the user app, the cloud, and potentially sleeping devices requires careful consideration. While Supabase Realtime efficiently pushes database changes to the Flutter app, pushing commands from the cloud to an ESP8266 that spends most of its time in deep sleep is problematic. Persistent connections (like MQTT or WebSockets) offer near-instant command delivery but are power-hungry, undermining the portability goal. The alternative, periodic polling by the ESP8266, conserves power but introduces command latency. If the device sleeps for 60 seconds between polling checks, a manual 'start' command from the app could take up to 60 seconds to be executed. This delay can significantly impact the user experience for manual control. A practical compromise involves the ESP8266 waking periodically (e.g., every 10-30 seconds) to both push its status and poll for commands stored in the `pending_command` field. To further mitigate latency for manual controls when the user's phone and the TriNode SmartMixer are on the same local network, implementing direct local communication (as discussed in Section 5.4) is highly recommended. This bypasses the cloud polling delay for commands, offering a much more responsive feel, while still using the cloud for logging and status synchronization.

### Table 2: Supabase Database Schema Outline

| Table Name        | Field Name        | Data Type     | Constraints/Notes                                         |
| :---------------- | :---------------- | :------------ | :-------------------------------------------------------- |
| **users** | (Managed by Supabase Auth) |               | Contains id (UUID), email, etc.                           |
| **devices** | `device_id`       | UUID          | Primary Key                                               |
|                   | `user_id`         | UUID          | Foreign Key -> users.id, ON DELETE CASCADE                |
|                   | `name`            | TEXT          | User-defined name                                         |
|                   | `status`          | TEXT          | e.g., 'online', 'offline'                                 |
|                   | `operating_mode`  | TEXT          | e.g., 'auto', 'manual'                                    |
|                   | `last_heartbeat`  | TIMESTAMPTZ   | Timestamp of last contact                                 |
| **mixing\_stations**| `station_id`      | UUID          | Primary Key                                               |
|                   | `device_id`       | UUID          | Foreign Key -> devices.device\_id, ON DELETE CASCADE      |
|                   | `station_index`   | INTEGER       | 1, 2, or 3                                                |
|                   | `motor_status`    | TEXT          | e.g., 'idle', 'running'                                   |
|                   | `sensor_status`   | TEXT          | e.g., 'container\_present', 'empty'                       |
|                   | `pending_command` | TEXT          | e.g., 'start', 'stop', NULL. Cleared after execution.     |
|                   | `last_updated`    | TIMESTAMPTZ   | Timestamp of last status change                           |
| **mix\_logs** | `log_id`          | UUID          | Primary Key                                               |
|                   | `station_id`      | UUID          | Foreign Key -> mixing\_stations.station\_id, ON DELETE SET NULL |
|                   | `user_id`         | UUID          | Foreign Key -> users.id, ON DELETE SET NULL               |
|                   | `start_time`      | TIMESTAMPTZ   |                                                           |
|                   | `end_time`        | TIMESTAMPTZ   |                                                           |
|                   | `duration_ms`     | INTEGER       | Calculated duration                                       |
|                   | `trigger_mode`    | TEXT          | 'auto' or 'manual'                                        |

## 5. Flutter Mobile Application

**5.1 Core Features & Screens:** The Flutter mobile application serves as the primary user interface for interacting with the TriNode SmartMixer system. Key features and corresponding screens include:

* **User Authentication:** Screens for user Login (email/password), Registration, and potentially Password Reset functionality, leveraging the `supabase_flutter` package to interact securely with Supabase Auth.
* **Device Registration/Management:** Functionality to add a new TriNode SmartMixer device to the user's account. This might involve scanning a QR code containing the `device_id`, manual entry, or a Wi-Fi provisioning process. Screens should also allow users to view their registered devices, assign custom names (`devices.name`), and remove devices.
* **Main Dashboard:** A central screen displaying the overall status of the selected TriNode SmartMixer device. It should clearly show the state of the mixing station (`mixing_stations.sensor_status`, `mixing_stations.motor_status`). This screen will utilize Supabase Realtime subscriptions to reflect status changes live without requiring manual refreshes.
* **Manual Control Interface:** Dedicated controls for the mixing station, likely presented on the dashboard or a detail screen. Simple 'Start Mixing' and 'Stop Mixing' buttons are essential. The interface should provide immediate visual feedback indicating that a command has been sent and reflect the actual motor status (`mixing_stations.motor_status`) once updated via Supabase Realtime.
* **Mode Selection:** Controls (e.g., a toggle switch or dropdown) allowing the user to switch the device's operating mode between 'Automatic' (sensor-triggered mixing) and 'Manual' (app-controlled mixing). This action would update the `devices.operating_mode` field in Supabase, which the ESP8266 firmware would then read and act upon.
* **Mixing Log Viewer:** A screen to display historical mixing data fetched from the `mix_logs` table in Supabase. It should present log entries clearly (e.g., station, start/end time, duration, trigger mode) and could offer filtering or sorting options (e.g., by date).

**5.2 UI/UX Considerations:**

* **Clarity and Simplicity:** The user interface must be intuitive and easy to navigate. Visual cues, such as distinct icons or color changes, should clearly represent the status of the mixing station (e.g., green for running, grey for idle, blue for container present). The layout should prioritize quick access to status information and manual controls.
* **Responsiveness:** The app must feel responsive. User actions like button presses should trigger immediate visual feedback (e.g., changing button state to 'sending...'). While backend communication and device execution might involve latency (especially with polling), the app should acknowledge user input instantly. Realtime updates received from Supabase are crucial for reflecting the device's actual state promptly.
* **Error Handling:** Robust error handling is necessary. The app should gracefully handle situations like loss of internet connectivity, inability to reach Supabase services, authentication failures, or errors reported by the device itself (if implemented). Clear, user-friendly error messages should be displayed.

### 5.3 Backend Connectivity (Flutter <-> Supabase)

**Supabase Flutter SDK:** The official `supabase_flutter` package is the recommended tool for integrating the Flutter app with Supabase. It provides convenient methods for authentication, performing database operations (CRUD - Create, Read, Update, Delete) on the defined tables (`devices`, `mixing_stations`, `mix_logs`), and setting up realtime subscriptions to listen for database changes. Secure interaction is typically handled via Row Level Security policies defined within Supabase, ensuring users can only access their own data.

**State Management:** Managing the asynchronous data flow from Supabase (initial data fetches, realtime updates, command responses) and reflecting it consistently in the UI requires a robust state management solution within Flutter. Popular choices like Provider, Riverpod, or BLoC/Cubit can help structure the application logic, separate concerns, and efficiently update the UI based on changing data states.

### 5.4 (Optional) Direct Local Network Communication

**Rationale:** As highlighted previously, relying solely on cloud-mediated commands for manual control can lead to noticeable latency due to the ESP8266's power-saving sleep and polling cycles. Implementing direct communication over the local Wi-Fi network, when the phone and TriNode SmartMixer are connected to the same network, can drastically reduce this latency for manual 'Start'/'Stop' commands.

**Implementation Sketch:** This requires additional firmware development on the ESP8266s to run a lightweight web server or listen for UDP packets on a specific port. The Flutter app would first need to discover the local IP address(es) of the TriNode SmartMixer device's ESP8266(s). This could be achieved using network discovery protocols like mDNS/Bonjour (requiring an mDNS library on the ESP) or potentially by having the ESP report its local IP to Supabase, which the app can then retrieve. Once the IP is known, the app can send commands (e.g., simple HTTP GET requests like `http://<ESP_IP>/start` or UDP packets) directly to the target ESP8266 over the local network. The ESP firmware would handle these local requests immediately, bypassing the cloud polling delay. Status updates and logging would still primarily occur via Supabase.

**User Experience and Synchronization:** The overall usability and perceived quality of the Flutter application are heavily influenced by the system's end-to-end latency and the reliability of data synchronization between the device, cloud, and app. Users generally expect mobile applications to react quickly to their input. While some delay in status updates reflecting automatic events might be acceptable, significant lag (several seconds or more) between pressing a 'Start Mixing' button in manual mode and the motor actually starting creates a poor user experience. Discrepancies between the state shown in the app and the actual state of the device, caused by network issues or synchronization problems, can lead to confusion and potentially incorrect operation. Implementing the optional local network communication path is therefore strongly advised as it directly addresses the manual control latency issue, offering a significantly improved, near-instantaneous feel when the user is on the same network as the device. The UI design should also incorporate visual indicators (e.g., loading spinners, 'updating...' messages) to manage user expectations during periods of communication or processing.

## 6. Operational Logic and Control

### 6.1 Firmware Logic (ESP8266)

**Initialization (Setup Phase):** Upon power-up or reset, each ESP8266 executes its setup routine. This involves: initializing GPIO pins for sensor input and motor driver control signals; configuring and connecting to the specified Wi-Fi network; establishing inter-ESP communication links if required (e.g., ESP-NOW pairing); potentially synchronizing time using an NTP server; registering itself with the Supabase backend or updating its status in the `devices` and `mixing_stations` tables (e.g., setting status to 'online').

**Main Loop (Operational Cycle):** After setup, the ESP8266 enters its main loop, which continuously executes the core operational logic:

* **Read Inputs:** Check the state of the connected sensor to detect container presence/absence.
* **Check for Commands:** Listen for incoming commands via the chosen inter-ESP communication channel (if applicable). Poll Supabase (e.g., check `pending_command` field) if using the polling method for cloud commands, or process commands received via a persistent connection listener or local network listener.
* **Determine Mode:** Check the current `operating_mode` ('auto' or 'manual'), potentially fetched periodically from Supabase or received via command.
* **Execute Control Logic:** Based on the current mode, sensor state, and any received commands, decide whether to start, stop, or continue running the motor. Implement logic to handle transitions and prioritize commands (e.g., manual stop overrides auto-start).
* **Control Motor:** Update the motor driver control signals (Enable, Direction, PWM for speed if implemented) accordingly.
* **Report Status:** If there's a change in sensor state, motor status, or periodically (heartbeat), send updates to the Supabase `mixing_stations` and `devices` tables. Log completed mixing events to the `mix_logs` table.
* **Power Management:** If no immediate action is required and the system is idle, enter a low-power sleep mode (e.g., deep sleep) for a configured duration. Configure wake-up sources: typically a timer for periodic checks/heartbeats, and potentially a GPIO interrupt triggered by a change in the sensor state (allowing instant wake-up when a container is placed or removed).

### 6.2 Automatic Mode Implementation

**Trigger:** When the firmware is in 'Automatic' mode (`devices.operating_mode == 'auto'`), the primary trigger is the sensor detecting the presence of a container (e.g., IR sensor digital output changes state, or load cell reading crosses a predefined threshold).

**Action:** Upon detecting a container, the ESP8266 activates the motor by sending the appropriate signals to the motor driver.

**Duration:** The motor runs for a predefined duration (which could be a system-wide setting or potentially configurable via the app/Supabase). Alternatively, the logic could be set to mix as long as the container remains present, stopping only when it's removed. This choice affects the user experience and potential use cases.

**Logging:** Once the mixing cycle is complete (either duration expires or container is removed), the ESP8266 records the event by sending the start time, end time, calculated duration, station ID, user ID, and trigger mode ('auto') to the `mix_logs` table in Supabase.

### 6.3 Manual Mode Implementation

**Trigger:** When the firmware is in 'Manual' mode (`devices.operating_mode == 'manual'`), sensor inputs related to container presence are ignored for triggering the motor. The triggers are explicit 'Start' or 'Stop' commands received for the mixing station. These commands originate from the Flutter app or Admin Panel and are relayed via Supabase (polling the `pending_command` field or pushed via persistent connection) or received directly over the local network.

**Action:** Upon receiving a valid 'Start' command, the ESP8266 activates the motor. Upon receiving a 'Stop' command, it deactivates the motor.

**Logging:** Similar to automatic mode, when a manual mixing session is stopped (by a 'Stop' command), the ESP8266 logs the event details (start time, end time, duration, station ID, user ID) to the `mix_logs` table, ensuring the `trigger_mode` is recorded as 'manual'.

### 6.4 Data Logging Strategy

**What to Log:** Essential data points for each mixing event include: `user_id`, `device_id`, `station_id`, `start_time`, `end_time`, `duration_ms`, and `trigger_mode`. If using sensors like load cells, logging the initial and final weight might provide valuable context. Additionally, logging device status changes (e.g., 'online'/'offline' transitions based on connectivity) and periodic heartbeats in the `devices` or `mixing_stations` tables is crucial for monitoring device health and availability.

**When to Log:** Mixing events should be logged upon completion. Status updates (motor, sensor) should be logged in near realtime as they occur to keep the app display accurate. Heartbeats should be logged periodically (e.g., every few minutes) when the device is online.

**How to Log:** The ESP8266 firmware will format the data (e.g., as a JSON payload) and send it to the Supabase backend. This is typically done via HTTPS POST/PATCH requests to the Supabase REST API endpoints for the respective tables. Using Supabase Edge Functions as an intermediary API layer could provide more robust data validation and processing before database insertion. The firmware must include error handling for logging attempts, potentially implementing a retry mechanism with backoff in case of temporary network failures, possibly storing logs locally in SPIFFS/LittleFS temporarily if the connection is down for an extended period.

**Coordination Across Distributed ESPs:** The design choice of three ESP8266s introduces potential coordination requirements, depending on the desired system behavior. If the three sensors operate entirely independently, minimal inter-ESP communication is needed; each ESP manages its sensor/motor and communicates directly with Supabase. However, if coordination is necessary (e.g., ensuring only one motor runs at a time due to power supply limits, implementing a global emergency stop, or having one ESP act as a central gateway for cloud communication), the complexity increases. An inter-ESP communication protocol (ESP-NOW or MQTT) must be implemented reliably. Specific message formats need to be defined for exchanging status information or relaying commands (e.g., "Request to start motor," "Coordinator: Grant motor usage," "All Sensors: Enter deep sleep"). Reliability mechanisms like acknowledgements and retries might be needed, especially with connectionless protocols like ESP-NOW. Using MQTT simplifies the topology with a central broker but introduces broker dependency and potential cloud latency even for local communication if a cloud broker is used. Maintaining a consistent view of the system state (e.g., the global `operating_mode`) across all ESPs and the cloud backend requires careful state management logic, especially considering potential network dropouts or device resets. Clear rules must be defined for state transitions, command precedence (e.g., does a manual 'stop' command from the app override an ongoing 'auto' mix?), and conflict resolution. For simplicity and robustness, the recommended approach is to minimize inter-ESP dependencies unless specific coordinated features are deemed essential.

## 7. Potential Enhancements

Beyond the core requirements, several enhancements could significantly improve the TriNode SmartMixer's functionality and user experience:

* **Variable Speed Control:** Implement PWM (Pulse Width Modulation) control for the DC motors via the motor driver. This would allow the user to adjust the mixing speed through the Flutter app, catering to different liquid viscosities or mixing requirements. The speed setting could be stored in Supabase.
* **Recipe Management:** Allow users to define multi-step mixing sequences (e.g., "Mix at speed 5 for 30s, pause 10s, mix at speed 8 for 15s") within the Flutter app. These recipes could be saved to the Supabase database and associated with the user's account, allowing them to easily trigger complex mixing profiles.
* **Liquid Level Sensing:** Integrate ultrasonic sensors or non-contact capacitive liquid level sensors to detect the approximate volume of liquid in the container. This could be used for logging purposes, preventing mixing in an empty container, or stopping automatically when a certain level is reached (if filling).
* **Temperature Monitoring:** Add digital temperature sensors (e.g., waterproof DS18B20) to monitor the liquid's temperature during mixing. This data could be logged, displayed in the app, or used to trigger alerts or modify mixing behavior (e.g., for temperature-sensitive reactions).
* **Improved Pairing & Provisioning:** Implement a more user-friendly Wi-Fi setup process instead of hardcoding credentials in the firmware. Libraries like WiFiManager allow the ESP8266 to create a temporary access point for the user to connect and enter their home Wi-Fi details via a web portal. A secure device pairing mechanism (beyond just knowing the `device_id`) could also be added.
* **Local Control Interface:** Add physical buttons (e.g., start/stop, mode switch) and a small OLED display (e.g., SSD1306) directly on the device enclosure. This would allow basic operation and status monitoring even without the mobile app or network connectivity.
* **Supabase Edge Functions:** Utilize Supabase Edge Functions (serverless functions) for more complex backend logic. Instead of having the ESP8266 or Flutter app perform complex data validation, aggregation, or trigger notifications directly via database operations, these tasks could be encapsulated in Edge Functions, leading to cleaner client code and more centralized backend control. For example, an Edge Function could process incoming log data or handle command validation before updating the database.

## 8. Conclusion

**8.1 Summary of Proposal:** The TriNode SmartMixer project, as proposed, represents a feasible and engaging application of IoT technologies. By integrating three ESP8266 microcontrollers, each managing a distinct sensor type and the mixing motor, with a Supabase cloud backend and a Flutter mobile application, the system provides a portable, intelligent solution for automating liquid mixing tasks. It offers both sensor-driven automatic operation and flexible manual control via the mobile app, along with valuable data logging capabilities.

**8.2 Alignment with Requirements:** The proposed design directly addresses the core requirements outlined in the initial query: utilization of three ESP8266 microcontrollers, sensor-triggered motor activation upon container placement, provision for both automatic and manual control modes, use of Supabase for backend services (authentication, data logging, admin capabilities), and a Flutter mobile application for the user interface.

**8.3 Key Challenges & Considerations:** Development should proceed with awareness of the key technical challenges inherent in this design. The complexity introduced by coordinating three separate ESP8266 microcontrollers, particularly regarding inter-device communication and synchronized state management, requires careful planning and implementation. Achieving meaningful battery life for a portable device with three Wi-Fi-enabled MCUs and motors necessitates aggressive power management strategies (deep sleep) and careful component selection, potentially impacting realtime responsiveness. Managing the latency associated with cloud communication for manual commands, especially when devices are sleeping, is crucial for user experience, making the implementation of direct local network control highly recommended.

**8.4 Next Steps:** The recommended path forward involves sourcing the selected hardware components (ESP8266 boards, sensors, geared motors, drivers, power components), developing detailed schematics for wiring, and adopting an incremental development approach. It would be prudent to start by implementing the core functionality for the mixing station (sensor reading, motor control, basic Supabase communication). Subsequently, cloud features like authentication, realtime updates, and logging can be integrated. Finally, the multi-sensor coordination (if required) and advanced features like local network control and power management can be tackled. Thorough prototyping and testing throughout the process, particularly focusing on communication reliability, power consumption under various operating conditions, and command latency, will be essential for a successful outcome.