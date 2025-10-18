import { StyleSheet, Text, View, Pressable } from 'react-native';
import { Link } from 'expo-router';
import { useTheme } from '@/providers/ThemeProvider';

export default function NotFoundScreen() {
  const { colors } = useTheme();

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <Text style={[styles.title, { color: colors.text }]}>404</Text>
      <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
        Oops! This page doesn&apos;t exist.
      </Text>
      <Link href="/" asChild>
        <Pressable
          style={[styles.button, { backgroundColor: colors.primary }]}
          android_ripple={{ color: 'rgba(255, 255, 255, 0.3)' }}
        >
          <Text style={styles.buttonText}>Go to Home</Text>
        </Pressable>
      </Link>
    </View>
  );
}

const styles = StyleSheet.create({
  button: {
    borderRadius: 8,
    paddingHorizontal: 24,
    paddingVertical: 12,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  container: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    padding: 24,
  },
  subtitle: {
    fontSize: 18,
    marginBottom: 32,
    textAlign: 'center',
  },
  title: {
    fontSize: 72,
    fontWeight: 'bold',
    marginBottom: 16,
  },
});
