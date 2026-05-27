import { Server, Socket } from 'socket.io';
import redisClient from '../redisClient.js';

// --- Redis Keys ---
// Using constants prevents typos and makes the code easier to maintain.
const POLICE_GEO_KEY = 'police_locations'; // A Redis Geospatial set for police locations.
const AMBULANCE_GEO_KEY = 'ambulance_locations'; // A Redis Geospatial set for ambulance locations.
const USER_SOCKET_HASH_KEY = 'user_sockets'; // A Redis Hash mapping userId to their unique socket.id.

// --- TypeScript Interfaces for Payloads ---
// Defining the shape of data from the client makes our code safer and easier to understand.
interface JoinPayload {
  userId: string;
  role: 'police' | 'driver';
  location?: { lat: number; lng: number };
}

interface LocationUpdatePayload {
  ambulanceId: string;
  lat: number;
  lng: number;
  heading?: number;
}

/**
 * Handles a new user connecting and identifying themselves.
 * @param socket The client's socket instance.
 * @param payload The data sent from the client (userId, role, location).
 */
export async function handleJoin(socket: Socket, payload: JoinPayload): Promise<void> {
  const { userId, role, location } = payload;
  if (!userId || !role) {
    console.warn('[LocationController] Invalid join payload:', payload);
    return;
  }

  console.log(`[LocationController] ✓ User joined: ${userId} with role ${role} (socket: ${socket.id})`);

  // Map the user's ID to their unique socket ID for direct messaging later.
  await redisClient.hSet(USER_SOCKET_HASH_KEY, userId, socket.id);
  console.log(`[LocationController] Mapped ${userId} -> socket ${socket.id}`);

  // If the user is a police officer, add them to the 'police' room and their location to Redis.
  if (role === 'police') {
    socket.join('police');
    console.log(`[LocationController] Police ${userId} joined 'police' room`);

    if (location?.lat && location?.lng) {
      await redisClient.geoAdd(POLICE_GEO_KEY, {
        longitude: location.lng,
        latitude: location.lat,
        member: userId,
      });
      console.log(`[LocationController] ✓ Added police ${userId} to geo index at (${location.lat}, ${location.lng})`);
    } else {
      console.warn(`[LocationController] Police ${userId} joined without location - alerts may not work`);
    }
  }
}

/**
 * Handles an ambulance's location update, broadcasting it and checking for proximity alerts.
 * @param io The main Socket.IO server instance.
 * @param payload The data from the ambulance (ambulanceId, lat, lng, heading).
 */
export async function handleUpdateLocation(io: Server, payload: LocationUpdatePayload): Promise<void> {
  const { ambulanceId, lat, lng, heading } = payload;
  if (!ambulanceId || lat == null || lng == null) {
    console.warn('[LocationController] Invalid location update payload:', payload);
    return;
  }

  console.log(`[LocationController] Location update from ${ambulanceId}: (${lat}, ${lng})${heading !== undefined ? ` heading: ${heading}°` : ''}`);

  // Store ambulance location in Redis for scan feature
  try {
    await redisClient.geoAdd(AMBULANCE_GEO_KEY, {
      longitude: lng,
      latitude: lat,
      member: ambulanceId,
    });
    console.log(`[LocationController] ✓ Stored ambulance ${ambulanceId} location in Redis`);
  } catch (err) {
    console.error('[LocationController] Error storing ambulance location:', err);
  }

  // 1. Broadcast the new location to ALL clients in the 'police' room for general map updates.
  const positionData = { ambulanceId, lat, lng, heading };
  io.to('police').emit('ambulancePositionUpdate', positionData);
  console.log(`[LocationController] Broadcasted position to 'police' room`);

  // 2. Perform a geospatial search in Redis to find police within a 2.5km radius.
  try {
    const nearbyPolice = await redisClient.geoSearch(POLICE_GEO_KEY,
      { longitude: lng, latitude: lat },
      { radius: 2.5, unit: 'km' }
    );

    if (nearbyPolice.length > 0) {
      console.log(`[LocationController] ⚠️ ALERT: Found ${nearbyPolice.length} nearby police: ${nearbyPolice.join(', ')}`);
      // 3. For each nearby officer, get their socket ID and send a targeted alert.
      for (const policeId of nearbyPolice) {
        const socketId = await redisClient.hGet(USER_SOCKET_HASH_KEY, policeId);
        if (socketId) {
          io.to(socketId).emit('ambulanceProximityAlert', {
            ambulanceId,
            message: `Ambulance ${ambulanceId} is approaching your location!`,
          });
          console.log(`[LocationController] --> Sent proximity alert to police ${policeId} (socket: ${socketId})`);
        } else {
          console.warn(`[LocationController] Could not find socket ID for police ${policeId}`);
        }
      }
    } else {
      console.log(`[LocationController] No nearby police found for ambulance ${ambulanceId}`);
    }
  } catch (err) {
    console.error('[LocationController] Error during Redis GEOSEARCH:', err);
  }
}

/**
 * Handles cleanup when a user disconnects.
 * @param socket The client's socket instance that disconnected.
 */
export async function handleDisconnect(socket: Socket): Promise<void> {
  console.log(`[LocationController] Socket disconnecting: ${socket.id}`);

  // To find out which user disconnected, we must do a reverse lookup.
  // We find the userId associated with the disconnected socket.id.
  const allUsers = await redisClient.hGetAll(USER_SOCKET_HASH_KEY);
  const userId = Object.keys(allUsers).find(key => allUsers[key] === socket.id);

  if (userId) {
    console.log(`[LocationController] User disconnected: ${userId}`);
    // Remove the user from our Redis data stores.
    await redisClient.hDel(USER_SOCKET_HASH_KEY, userId);
    await redisClient.zRem(POLICE_GEO_KEY, userId); // zRem removes from geo index
    await redisClient.zRem(AMBULANCE_GEO_KEY, userId); // Also clean up ambulance location
    console.log(`[LocationController] ✓ Cleaned up data for ${userId}`);
  } else {
    console.log(`[LocationController] Socket ${socket.id} disconnected (no user mapping found)`);
  }
}
