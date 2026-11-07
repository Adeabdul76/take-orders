# Firebase setup (one time, about 10 minutes)

This lets all cafe phones share the same menu, prices, logo and orders.
Firebase is Google's online database. The free plan (Spark) is enough for a
cafe and does **not** need a credit card.

You only do this once, on a computer, with your Google account.

## 1. Create the project

1. Go to https://console.firebase.google.com and sign in with your Google account.
2. Click **Create a project** (or **Add project**).
3. Name it, for example `ishola-cafe`. Click **Continue**.
4. Turn **Google Analytics** off. It isn't needed. Click **Create project** and wait, then **Continue**.

## 2. Turn on the database (Firestore)

1. In the left menu click **Build > Firestore Database**, then **Create database**.
2. Location: choose **asia-southeast1 (Singapore)**, the closest to Penang. Click **Next**.
   (You can't change the location later.)
3. Choose **Start in production mode** and click **Create**.
4. When it opens, click the **Rules** tab at the top.
5. Delete everything in the box. Open the file
   [`firestore.rules`](firestore.rules) in this GitHub repo, copy **all** of it, and paste it into the box.
6. Click **Publish**.

## 3. Turn on "Anonymous" sign-in

The phones use this to connect safely without email accounts.

1. In the left menu click **Build > Authentication**, then **Get started**.
2. On the **Sign-in method** tab, click **Anonymous**, switch it **on**, and click **Save**.

## 4. Register the Android app

1. Click the **gear icon** (top left, next to "Project Overview") > **Project settings**.
2. Under **Your apps**, click the **Android** icon.
3. **Android package name:** type exactly `my.cafe.take_orders`
4. **App nickname:** `Take Orders`. Leave SHA-1 empty.
5. Click **Register app**.
6. Click **Download google-services.json**.
7. You can skip the remaining steps on that page (click **Next** / **Continue to console**).

## 5. Send the settings to Claude

Open the downloaded `google-services.json` with Notepad, copy everything, and
paste it into the chat with Claude.

The file is not a password. It only tells the app which Firebase project to
use, and the rules from step 2 protect your data. Claude puts the values into
`lib/firebase_config.dart`, and GitHub then builds a new app with sharing turned on.

## 6. On the phones

**Main (owner) phone:** after installing the new version, open
**Menu > Share with other phones > Share this cafe**, then choose a PIN.
Your menu, photos, logo, shop details and past orders are copied up once. The
screen then shows your **cafe code** (6 letters) and the **PIN**.

**Each staff phone:** install the app. On the first screen tap **Join my cafe**,
then type the cafe code and PIN. The menu appears automatically.

### Good to know

- **No internet?** The app keeps working. Orders and changes are saved on the phone and sent automatically when the internet comes back.
- **Order numbers:** each phone gets a letter (A = main phone, B, C, ...), so receipts look like `#A012`, `#B003`. Two phones never print the same number, even offline.
- **The daily summary** includes orders from all phones.
- **Keep the PIN private.** Anyone with the code and PIN can see and change the menu and orders.
- **Free plan limits** (50,000 reads and 20,000 writes per day) are far more than a cafe uses.
