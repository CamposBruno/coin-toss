import { useAuth0 } from 'react-native-auth0';
import { apiClient } from './api';

export function useAuth() {
  const auth0 = useAuth0();

  const login = async () => {
    try {
      const credentials = await auth0.authorize();
      if (credentials?.accessToken) {
        apiClient.setAuthToken(credentials.accessToken);
      }
      return credentials;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  };

  const logout = async () => {
    try {
      await auth0.clearSession();
      apiClient.setAuthToken(null);
    } catch (error) {
      console.error('Logout error:', error);
      throw error;
    }
  };

  return {
    ...auth0,
    login,
    logout,
  };
}

export interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: {
    id: string;
    email: string;
    name: string;
    picture?: string;
  } | null;
}
