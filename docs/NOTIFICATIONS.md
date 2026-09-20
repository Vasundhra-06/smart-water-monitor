# Push Notifications Guide — Smart Water Monitor

## 🔔 Firebase Cloud Messaging (FCM) Integration

Notifications trigger automatically when an abnormal trend peak is detected:

```text
⚠️ Water Quality Alert
Water quality in Main Tank is deteriorating.
An abnormal turbidity peak (4.62 NTU) has been detected.
Please inspect/clean the tank.
```

### Alert Deduplication
To prevent notification spam, the alert engine enforces a 4-hour suppression window per tank for identical parameter warnings unless severity escalates from `WARNING` to `CRITICAL`.
