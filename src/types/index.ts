export interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
  role: 'host' | 'guest' | 'both';
  isVerified: boolean;
  createdAt: string;
}

export interface Event {
  id: string;
  title: string;
  description: string;
  type: EventType;
  hostId: string;
  host: User;
  date: string;
  startTime: string;
  endTime?: string;
  location: Location;
  maxGuests: number;
  currentGuests: number;
  status: EventStatus;
  guests: User[];
  createdAt: string;
  updatedAt: string;
}

export type EventType =
  | 'dinner'
  | 'game-night'
  | 'movie-night'
  | 'networking'
  | 'workshop'
  | 'outdoor'
  | 'other';

export type EventStatus = 'scheduled' | 'in-progress' | 'completed' | 'cancelled';

export interface Location {
  address: string;
  city: string;
  state: string;
  zipCode: string;
  coordinates: {
    latitude: number;
    longitude: number;
  };
  isVerified: boolean;
}

export interface Review {
  id: string;
  eventId: string;
  userId: string;
  user: User;
  rating: number;
  comment?: string;
  createdAt: string;
}

export interface Invitation {
  id: string;
  eventId: string;
  event: Event;
  guestId: string;
  guest: User;
  status: InvitationStatus;
  sentAt: string;
  respondedAt?: string;
}

export type InvitationStatus = 'pending' | 'accepted' | 'declined';

export interface UserPreferences {
  role: 'host' | 'guest' | 'both';
  eventTypes: EventType[];
  maxDistance: number; // in miles
  isPaused: boolean;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
  success: boolean;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}
