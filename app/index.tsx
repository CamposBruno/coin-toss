import { StyleSheet, Text, View, ScrollView } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { useTheme } from '@/providers/ThemeProvider';

export default function HomeScreen() {
  const { colors, isDark } = useTheme();

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar style={isDark ? 'light' : 'dark'} />
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text style={[styles.title, { color: colors.text }]}>🐝</Text>
          <Text style={[styles.title, { color: colors.text }]}>Welcome to The Hyve</Text>
          <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
            Connect. Host. Experience.
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { color: colors.text }]}>About The Hyve</Text>
          <Text style={[styles.description, { color: colors.textSecondary }]}>
            The Hyve is a revolutionary social networking app that helps match everyday people
            looking to socialize as either event hosts or guests. Say goodbye to loneliness and
            hello to meaningful connections!
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { color: colors.text }]}>How It Works</Text>
          <View style={styles.feature}>
            <Text style={[styles.featureIcon, { color: colors.primary }]}>🎯</Text>
            <Text style={[styles.featureText, { color: colors.textSecondary }]}>
              Our algorithm matches you as either a host or guest
            </Text>
          </View>
          <View style={styles.feature}>
            <Text style={[styles.featureIcon, { color: colors.primary }]}>🏠</Text>
            <Text style={[styles.featureText, { color: colors.textSecondary }]}>
              Hosts plan intimate events in their area
            </Text>
          </View>
          <View style={styles.feature}>
            <Text style={[styles.featureIcon, { color: colors.primary }]}>🤝</Text>
            <Text style={[styles.featureText, { color: colors.textSecondary }]}>
              Connect with local people and build lasting friendships
            </Text>
          </View>
          <View style={styles.feature}>
            <Text style={[styles.featureIcon, { color: colors.primary }]}>⭐</Text>
            <Text style={[styles.featureText, { color: colors.textSecondary }]}>
              Rate your experience and discover great events
            </Text>
          </View>
        </View>

        <View style={styles.footer}>
          <Text style={[styles.footerText, { color: colors.textSecondary }]}>
            MVP Foundation v1.0.0
          </Text>
          <Text style={[styles.footerText, { color: colors.textSecondary }]}>
            Built with Expo SDK 52
          </Text>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: 24,
    paddingTop: 60,
  },
  description: {
    fontSize: 16,
    lineHeight: 24,
  },
  feature: {
    alignItems: 'center',
    flexDirection: 'row',
    marginBottom: 12,
  },
  featureIcon: {
    fontSize: 24,
    marginRight: 12,
  },
  featureText: {
    flex: 1,
    fontSize: 16,
    lineHeight: 24,
  },
  footer: {
    alignItems: 'center',
    borderTopColor: 'lightgray',
    borderTopWidth: 1,
    marginTop: 32,
    paddingTop: 24,
  },
  footerText: {
    fontSize: 14,
    marginBottom: 4,
  },
  header: {
    alignItems: 'center',
    marginBottom: 32,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
    marginBottom: 12,
  },
  subtitle: {
    fontSize: 18,
    textAlign: 'center',
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    marginBottom: 8,
    textAlign: 'center',
  },
});
