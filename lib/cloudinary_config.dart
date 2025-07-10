// cloudinary_config.dart

/// Cloudinary configuration for uploading profile pictures.
/// These values come from your Cloudinary dashboard and apply to all users.

const String cloudinaryCloudName = 'dq3r2y7xt'; // ✅ Your actual cloud name
const String cloudinaryUploadPreset = 'flutter_user_upload';         // ✅ Your unsigned preset name

/// Constructs the base Cloudinary upload URL.
String get cloudinaryUploadUrl =>
    'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

/// Generates a user-specific public ID for profile pictures.
/// e.g., 'pfp_abc123uid'
String generateUserPublicId(String uid) => 'pfp_$uid';

/// Optional folder path per user to organize uploads
/// e.g., 'users/abc123uid'
String generateUserFolder(String uid) => 'users/$uid';