# 🚑 Ambulance Tracking System (ATS)

A real-time GPS-based Ambulance Tracking System designed to improve emergency response efficiency by providing live ambulance tracking, geospatial proximity alerts, and coordination between ambulance drivers and traffic police.

\---

# 📌 Overview

The Ambulance Tracking System (ATS) is a full-stack real-time emergency coordination platform developed using modern web and mobile technologies.

The system helps traffic police proactively clear traffic for ambulances by:

* Tracking ambulance locations in real time
* Sending automated proximity alerts
* Providing live map visualization
* Reducing emergency response delays

This project was developed as a Final Year Engineering Project for Bachelor of Engineering in Computer Science \& Engineering.

\---

# ✨ Features

## 🚑 Driver Module

* User Registration \& Login
* Start Emergency Mission
* End Emergency Mission
* Live GPS Broadcasting
* Real-Time Route Tracking
* Speed Monitoring

## 👮 Police Module

* Real-Time Ambulance Monitoring
* Proximity Alert Notifications
* Interactive Map Interface
* Multi-Ambulance Tracking
* Radius-Based Alert Detection

## 🌐 System Features

* Real-Time Communication using Socket.IO
* Redis Geospatial Indexing
* JWT Authentication
* MongoDB Database
* OpenStreetMap Integration
* Cross-Platform Mobile Support

\---

# 🛠️ Tech Stack

|Technology|Purpose|
|-|-|
|Flutter|Frontend Mobile Application|
|Node.js|Backend Runtime|
|Express.js|REST API Framework|
|TypeScript|Backend Development|
|MongoDB|Primary Database|
|Redis|Geospatial Processing|
|Socket.IO|Real-Time Communication|
|OpenStreetMap|Map Integration|
|JWT|Authentication|
|bcrypt|Password Security|

\---

# 🏗️ System Architecture

```text
Driver App
    ↓
Socket.IO Communication
    ↓
Node.js + Express Backend
    ↓
MongoDB + Redis
    ↓
Police Dashboard
```

\---

# 📱 Modules

## 1️⃣ Driver Module

The Driver Module allows ambulance drivers to:

* Go Live
* Share real-time GPS coordinates
* Start and end missions
* Broadcast ambulance movement

## 2️⃣ Police Module

The Police Module allows officers to:

* Monitor ambulances in real time
* Receive alerts within a 2.5 km radius
* Manage traffic proactively

\---

# 🔄 Workflow

1. Driver logs into the application
2. Driver starts emergency mission
3. GPS coordinates are continuously sent to the backend
4. Redis performs geospatial proximity detection
5. Nearby police officers receive alerts
6. Police clear traffic for ambulance movement

\---

# 📊 Performance Results

|Parameter|Result|
|-|-|
|End-to-End Latency|< 1 second|
|Alert Accuracy|99.9%|
|Redis Lookup Speed|\~4 ms|
|Network Usage|\~10 KB/min|
|System Stability|98%|

\---

# 🔐 Security Features

* JWT-Based Authentication
* Role-Based Access Control
* bcrypt Password Hashing
* Secure Session Management

\---

# 📂 Project Structure

```text
ATS/
│
├── frontend/
│   ├── driver\_app/
│   └── police\_app/
│
├── backend/
│   ├── controllers/
│   ├── routes/
│   ├── socket/
│   ├── middleware/
│   └── services/
│
├── database/
│   ├── mongodb/
│   └── redis/
│
└── docs/
```

\---

## Backend Setup

```bash
cd backend
npm install
npm run dev
```

\---

## Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

\---

# 🔧 Environment Variables

Create a `.env` file inside backend directory.

```env
PORT=5000
MONGO\_URI=your\_mongodb\_url
REDIS\_URL=your\_redis\_url
JWT\_SECRET=your\_secret\_key
```

\---

# 📸 Screenshots

* Home Interface
* Login Interface
* Live GPS Tracking
* Police Monitoring Dashboard

\---

# 🎯 Objectives Achieved

✅ Real-Time Ambulance Tracking  
✅ Geospatial Proximity Detection  
✅ Automated Police Alerts  
✅ Low-Latency Communication  
✅ Secure Authentication  
✅ Interactive Map Visualization

\---

# 🚀 Future Scope

* AI-Based Route Prediction
* Traffic Signal Integration
* Push Notifications
* Offline Mode Support
* Analytics Dashboard
* Smartwatch Integration

\---

# 📚 References

1. GPS-Based Ambulance Tracking System
2. Smart Ambulance System using IoT
3. Real-Time Vehicle Tracking using GPS and GSM
4. Intelligent Transportation Systems for Emergency Vehicles

\---

# 🏫 College

Department of Computer Science \& Engineering  
Sipna College of Engineering \& Technology, Amravati

\---

# 📄 License

This project is developed for academic and research purposes.

