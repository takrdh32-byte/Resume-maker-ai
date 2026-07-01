import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/photoslibrary/v1.dart' as photos;
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../services/plan_manager.dart';

class CloudRecoveryService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/photoslibrary.readonly',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  // गूगल साइन-इन करके ऑथेंटिकेटेड क्लाइंट लौटाएगा
  static Future<AutoRefreshingAuthClient?> signInAndGetClient() async {
    final GoogleSignInAccount? account = await _googleSignIn.signIn();
    if (account == null) return null;

    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    return client as AutoRefreshingAuthClient?;
  }

  // Google Photos के ट्रैश और आर्काइव से तस्वीरों की लिस्ट (बेस URL)
  static Future<List<String>> getRecoverablePhotos() async {
    final client = await signInAndGetClient();
    if (client == null) return [];

    final photosApi = photos.PhotosLibraryApi(client);
    final List<String> photoUrls = [];

    try {
      var response = await photosApi.mediaItems.search(photos.SearchMediaItemsRequest(
        filters: photos.Filters(includeArchivedMedia: true),
      ));
      if (response.mediaItems != null) {
        for (var item in response.mediaItems!) {
          photoUrls.add(item.baseUrl!);
        }
      }
    } catch (_) {}

    return photoUrls;
  }

  // Gmail से पुरानी ईमेल्स में JPEG/PNG अटैचमेंट ढूँढ़ो
  static Future<List<String>> getEmailAttachments() async {
    final client = await signInAndGetClient();
    if (client == null) return [];

    final gmailApi = gmail.GmailApi(client);
    final List<String> attachmentNames = [];

    try {
      var messages = await gmailApi.users.messages.list(
        'me',
        q: 'has:attachment filename:(jpg OR jpeg OR png)',
        maxResults: 10,
      );
      if (messages.messages != null) {
        for (var msg in messages.messages!) {
          var fullMsg = await gmailApi.users.messages.get('me', msg.id!);
          if (fullMsg.payload?.parts != null) {
            for (var part in fullMsg.payload!.parts!) {
              if (part.mimeType?.startsWith('image/') == true &&
                  part.body?.attachmentId != null) {
                attachmentNames.add(part.filename ?? 'attachment_${msg.id}');
              }
            }
          }
        }
      }
    } catch (_) {}

    return attachmentNames;
  }

  // साइन आउट
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}