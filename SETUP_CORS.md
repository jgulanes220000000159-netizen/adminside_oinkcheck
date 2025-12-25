# How to Configure CORS for Firebase Storage

## Method 1: Using Google Cloud Console (Web UI)

1. **Go to Google Cloud Console:**
   - Visit: https://console.cloud.google.com/storage/browser
   - Make sure you're signed in with the account that has access to your Firebase project

2. **Select Your Bucket:**
   - Look for: `oinkcheck-d07df.appspot.com` or `oinkcheck-d07df.firebasestorage.app`
   - Click on the bucket name

3. **Configure CORS:**
   - Click on the **"Configuration"** tab
   - Scroll down to find **"CORS configuration"**
   - Click **"Edit CORS configuration"**
   - Paste this JSON:
   ```json
   [
     {
       "origin": ["*"],
       "method": ["GET", "HEAD"],
       "maxAgeSeconds": 3600
     }
   ]
   ```
   - Click **"Save"**

## Method 2: Using Command Line (if you have gsutil installed)

1. **Install Google Cloud SDK** (if not installed):
   - Download from: https://cloud.google.com/sdk/docs/install
   - Follow installation instructions

2. **Authenticate:**
   ```bash
   gcloud auth login
   ```

3. **Set your project:**
   ```bash
   gcloud config set project oinkcheck-d07df
   ```

4. **Apply CORS configuration:**
   ```bash
   gsutil cors set cors.json gs://oinkcheck-d07df.appspot.com
   ```
   
   Or if your bucket uses the new format:
   ```bash
   gsutil cors set cors.json gs://oinkcheck-d07df.firebasestorage.app
   ```

5. **Verify it worked:**
   ```bash
   gsutil cors get gs://oinkcheck-d07df.appspot.com
   ```

## Method 3: Using Firebase CLI (Alternative)

If you have Firebase CLI installed:

1. **Login to Firebase:**
   ```bash
   firebase login
   ```

2. **Set your project:**
   ```bash
   firebase use oinkcheck-d07df
   ```

3. **Use gsutil through Firebase:**
   ```bash
   gsutil cors set cors.json gs://oinkcheck-d07df.appspot.com
   ```

## Important Notes:

- The `cors.json` file is already created in your project root
- After configuring CORS, it may take a few minutes to take effect
- Make sure you have the correct permissions to modify the bucket
- If you get permission errors, you may need to be added as an owner/editor in Google Cloud Console

## Troubleshooting:

If you can't find CORS in Google Cloud Console:
- Make sure you're looking at the Storage bucket, not Firebase Storage rules
- CORS configuration is in Google Cloud Console, not Firebase Console
- You may need to enable the Cloud Storage API first

