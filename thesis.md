# AMBULANCE TRACKING SYSTEM (ATS)

## A Real-Time Emergency Vehicle Tracking and Proximity Alert Platform

\---

### A Thesis Submitted in Partial Fulfillment of the Requirements for the Degree of

## Bachelor of Engineering / Bachelor of Technology

### In

## Computer Science and Engineering 

\---

**Submitted By:
Dhananjay V Ladhi** (Student) 

**Under the Guidance of:
\[A.A.Bardekar]** (Project Guide)

\---

**Department of Computer Science and Engineering
\[SIPNA COET Amravati]
\[Sant gadge Baba University]
Academic Year: 2025–2026**



## ABSTRACT

Emergency medical services (EMS) play a critical role in saving lives during medical emergencies. The timely arrival of ambulances at the scene of an emergency and the swift transportation of patients to medical facilities are decisive factors in patient survival rates. However, in urban environments, ambulance response times are significantly impacted by traffic congestion, inefficient route management, and poor coordination between emergency vehicles and traffic control personnel.

This thesis presents the design, development, and implementation of the **Ambulance Tracking System (ATS)** — a comprehensive real-time emergency vehicle tracking and proximity alert platform. The system addresses the critical need for improved coordination between ambulance drivers and traffic police officers by providing real-time GPS-based location tracking, geospatial proximity alerting, and an interactive map-based user interface.



The ATS employs a modern full-stack architecture comprising a **Node.js/TypeScript backend** with **Express.js** for RESTful API services, **Socket.IO** for bidirectional real-time communication, **MongoDB** for persistent data storage, and **Redis** for high-performance geospatial indexing and in-memory caching. The mobile frontend is built using **Flutter (Dart)**, leveraging **OpenStreetMap** via the `flutter\_map` library for map rendering, the `geolocator` package for device GPS integration, and the `socket\_io\_client` for seamless real-time communication with the backend.

The system supports two primary user roles: **Ambulance Drivers** who broadcast their real-time GPS locations during emergency missions, and **Traffic Police Officers** who receive visual map updates and targeted proximity alerts when an ambulance approaches within a configurable radius (default: 2.5 kilometers). The proximity detection mechanism utilizes Redis geospatial commands (`GEOADD`, `GEOSEARCH`) to perform efficient spatial queries, achieving sub-100-millisecond query latency.



Key results demonstrate that the system achieves an end-to-end location update latency of less than one second, proximity detection accuracy of 99.9%+ (leveraging the Haversine formula), and efficient network utilization averaging approximately 10 KB per minute per active user. The system has been successfully tested with multiple concurrent ambulances and police officers, demonstrating its viability as a real-world emergency coordination tool.



**Keywords:** Real-Time Tracking, GPS, WebSocket, Socket.IO, Geospatial Computing, Emergency Response, Flutter, Node.js, Redis, MongoDB, Proximity Alert, Ambulance Tracking





**LIST OF CONTENTS**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| Chapter No. | Title                                | Subtopics                                                    |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| Chapter 1   | Introduction                         | 1.1 Introduction                                             |**

**|             |                                      | 1.2 Problem Statement                                        |**

**|             |                                      | 1.3 Objectives                                               |**

**|             |                                      | 1.4 Scope of the Project                                     |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| Chapter 2   | Literature Review                    | -                                                            |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| Chapter 3   | System Analysis and Design           | 3.1 Existing System                                          |**

**|             |                                      | 3.2 Proposed System                                          |**

**|             |                                      | 3.3 System Architecture                                      |**

**|             |                                      | 3.4 Modules                                                  |**

**|             |                                      |    • Driver Module                                           |**

**|             |                                      |    • Police Module                                           |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| Chapter 4   | Implementation                       | 4.1 Technologies Used                                        |**

**|             |                                      | 4.2 Backend Development                                      |**

**|             |                                      | 4.3 Frontend Development                                     |**

**|             |                                      | 4.4 Database Management                                      |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| Chapter 5   | Results and Discussion               | 5.1 Achievements Table                                       |**

**|             |                                      | 5.2 Technologies Used Table                                  |**

**|             |                                      | 5.3 Key Results                                              |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| Chapter 6   | Conclusion                           | -                                                            |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| Chapter 7   | Future Scope                         | -                                                            |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| -           | References                           | -                                                            |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**

**| -           | List of Publications                 | -                                                            |**

**+-------------+--------------------------------------+--------------------------------------------------------------+**



