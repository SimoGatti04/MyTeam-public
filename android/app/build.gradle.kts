import java.io.FileInputStream
import java.security.KeyStore
import java.security.MessageDigest
import java.security.cert.X509Certificate
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun normalizeSha256Fingerprint(value: String): String =
    value.trim().replace(":", "").lowercase()

fun isSha256Fingerprint(value: String): Boolean =
    Regex("^[0-9a-f]{64}$").matches(normalizeSha256Fingerprint(value))

fun matchesSha256Fingerprint(actual: String, expected: String): Boolean =
    isSha256Fingerprint(actual) &&
        isSha256Fingerprint(expected) &&
        normalizeSha256Fingerprint(actual) == normalizeSha256Fingerprint(expected)

fun hasAtLeast25YearsRemaining(notAfter: LocalDate, today: LocalDate): Boolean =
    !notAfter.isBefore(today.plusYears(25))

fun signingChannelMatchesUpdater(channel: String, qaUpdaterEnabled: Boolean): Boolean =
    (channel == "qa" && qaUpdaterEnabled) ||
        (channel == "production" && !qaUpdaterEnabled)


val androidSigningChannel = System.getenv("MYTEAM_ANDROID_SIGNING_CHANNEL")
    .orEmpty()
    .trim()
    .lowercase()
val flutterDartDefines = (project.findProperty("dart-defines") as? String)
    .orEmpty()
    .split(",")
    .mapNotNull { encoded ->
        runCatching {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        }.getOrNull()
    }
val qaUpdaterEnabled = "MYTEAM_UPDATER_QA=true" in flutterDartDefines
val androidApplicationId = when (androidSigningChannel) {
    "qa" -> "com.example.myteam_video_app"
    else -> "it.simogatti.myteam"
}
val signingEnvironmentPrefix = when (androidSigningChannel) {
    "qa" -> "MYTEAM_ANDROID_QA"
    "production" -> "MYTEAM_ANDROID_PROD"
    else -> null
}
val releaseKeystorePath = signingEnvironmentPrefix
    ?.let { System.getenv("${it}_KEYSTORE_PATH") }
    .orEmpty()
val releaseStorePassword = signingEnvironmentPrefix
    ?.let { System.getenv("${it}_STORE_PASSWORD") }
    .orEmpty()
val releaseKeyAlias = signingEnvironmentPrefix
    ?.let { System.getenv("${it}_KEY_ALIAS") }
    .orEmpty()
val releaseKeyPassword = signingEnvironmentPrefix
    ?.let { System.getenv("${it}_KEY_PASSWORD") }
    .orEmpty()
val productionCertificateSha256 = System.getenv("MYTEAM_ANDROID_PROD_CERT_SHA256")
    .orEmpty()
    .let(::normalizeSha256Fingerprint)
val qaCertificateSha256 = System.getenv("MYTEAM_ANDROID_QA_CERT_SHA256")
    .orEmpty()
    .let(::normalizeSha256Fingerprint)
val releaseKeystore = releaseKeystorePath.takeIf(String::isNotBlank)?.let(::File)
val releaseKeystoreIsExternal = releaseKeystore?.let { keystore ->
    runCatching {
        val flutterRepositoryRoot = rootProject.projectDir.canonicalFile.parentFile
        flutterRepositoryRoot != null &&
            File(flutterRepositoryRoot, "pubspec.yaml").isFile &&
            keystore.isFile &&
            keystore.isAbsolute &&
            !keystore.canonicalFile.toPath().startsWith(flutterRepositoryRoot.toPath())
    }.getOrDefault(false)
} == true
val releaseSigningReady =
    signingEnvironmentPrefix != null &&
        releaseKeystorePath.isNotBlank() &&
        releaseStorePassword.isNotBlank() &&
        releaseKeyAlias.isNotBlank() &&
        releaseKeyPassword.isNotBlank() &&
        releaseKeystoreIsExternal &&
        (androidSigningChannel != "production" ||
            (isSha256Fingerprint(productionCertificateSha256) &&
                isSha256Fingerprint(qaCertificateSha256) &&
                productionCertificateSha256 != qaCertificateSha256))

val testReleaseFingerprintGuard = tasks.register("testReleaseFingerprintGuard") {
    doLast {
        val actual = "ab".repeat(32)
        val colonSeparated = actual.chunked(2).joinToString(":")
        check(matchesSha256Fingerprint(actual, colonSeparated)) {
            "Fingerprint guard must accept the same certificate digest in colon-separated form."
        }
        check(!matchesSha256Fingerprint(actual, "cd".repeat(32))) {
            "Fingerprint guard must reject a different certificate digest."
        }
        check(!isSha256Fingerprint("not-a-fingerprint")) {
            "Fingerprint guard must reject malformed allowlist values."
        }
        check(
            hasAtLeast25YearsRemaining(
                LocalDate.of(2051, 1, 1),
                LocalDate.of(2026, 1, 1),
            ),
        ) {
            "Certificate policy must accept at least 25 years of remaining validity."
        }
        check(
            !hasAtLeast25YearsRemaining(
                LocalDate.of(2050, 12, 31),
                LocalDate.of(2026, 1, 1),
            ),
        ) {
            "Certificate policy must reject less than 25 years of remaining validity."
        }
        check(signingChannelMatchesUpdater("qa", qaUpdaterEnabled = true))
        check(!signingChannelMatchesUpdater("qa", qaUpdaterEnabled = false))
        check(signingChannelMatchesUpdater("production", qaUpdaterEnabled = false))
        check(!signingChannelMatchesUpdater("production", qaUpdaterEnabled = true))
    }
}

val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    dependsOn(testReleaseFingerprintGuard)
    doLast {
        val missing = buildList {
            if (signingEnvironmentPrefix == null) {
                add("MYTEAM_ANDROID_SIGNING_CHANNEL (must be qa or production)")
            } else if (!signingChannelMatchesUpdater(androidSigningChannel, qaUpdaterEnabled)) {
                add("MYTEAM_ANDROID_SIGNING_CHANNEL (must match the MYTEAM_UPDATER_QA compile-time define)")
            }
            if (releaseKeystorePath.isBlank()) add("${signingEnvironmentPrefix ?: "MYTEAM_ANDROID_<CHANNEL>"}_KEYSTORE_PATH")
            if (releaseStorePassword.isBlank()) add("${signingEnvironmentPrefix ?: "MYTEAM_ANDROID_<CHANNEL>"}_STORE_PASSWORD")
            if (releaseKeyAlias.isBlank()) add("${signingEnvironmentPrefix ?: "MYTEAM_ANDROID_<CHANNEL>"}_KEY_ALIAS")
            if (releaseKeyPassword.isBlank()) add("${signingEnvironmentPrefix ?: "MYTEAM_ANDROID_<CHANNEL>"}_KEY_PASSWORD")
            if (releaseKeystorePath.isNotBlank() && releaseKeystore?.isFile != true) {
                add("${signingEnvironmentPrefix}_KEYSTORE_PATH (must reference an existing file)")
            } else if (releaseKeystore != null && !releaseKeystoreIsExternal) {
                add("${signingEnvironmentPrefix}_KEYSTORE_PATH (must be absolute and outside the repository)")
            }
            if (androidSigningChannel == "production") {
                if (!isSha256Fingerprint(productionCertificateSha256)) {
                    add("MYTEAM_ANDROID_PROD_CERT_SHA256 (must be the approved 32-byte SHA-256 certificate fingerprint)")
                }
                if (!isSha256Fingerprint(qaCertificateSha256)) {
                    add("MYTEAM_ANDROID_QA_CERT_SHA256 (must identify the separate QA signer)")
                } else if (productionCertificateSha256 == qaCertificateSha256) {
                    add("MYTEAM_ANDROID_PROD_CERT_SHA256 (must differ from the QA signer fingerprint)")
                }
            }
        }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Refusing release build: channel-specific external Android signing inputs are missing or invalid: ${missing.joinToString()}. " +
                    "Debug signing is never used as a release fallback.",
            )
        }

        if (androidSigningChannel == "production") {
            val keystoreFile = requireNotNull(releaseKeystore)
            val password = releaseStorePassword.toCharArray()
            val store = sequenceOf("JKS", "PKCS12").mapNotNull { type ->
                runCatching {
                    KeyStore.getInstance(type).apply {
                        FileInputStream(keystoreFile).use { load(it, password) }
                    }
                }.getOrNull()
            }.firstOrNull() ?: throw GradleException(
                "Refusing production release: external Android keystore cannot be opened.",
            )
            val privateKey = runCatching {
                store.getKey(releaseKeyAlias, releaseKeyPassword.toCharArray())
            }.getOrNull()
            if (privateKey !is java.security.PrivateKey) {
                throw GradleException(
                    "Refusing production release: configured alias does not unlock a private signing key.",
                )
            }
            val certificate = store.getCertificate(releaseKeyAlias)
                ?: throw GradleException(
                    "Refusing production release: configured key alias has no certificate.",
                )
            val actualFingerprint = MessageDigest.getInstance("SHA-256")
                .digest(certificate.encoded)
                .joinToString("") { byte -> "%02x".format(byte) }
            if (!matchesSha256Fingerprint(actualFingerprint, productionCertificateSha256)) {
                throw GradleException(
                    "Refusing production release: keystore certificate does not match the approved fingerprint.",
                )
            }
            val x509Certificate = certificate as? X509Certificate
                ?: throw GradleException(
                    "Refusing production release: signing certificate is not an X.509 certificate.",
                )
            val notAfter = x509Certificate.notAfter.toInstant()
                .atZone(ZoneOffset.UTC)
                .toLocalDate()
            val today = LocalDate.now(ZoneOffset.UTC)
            if (!hasAtLeast25YearsRemaining(notAfter, today)) {
                throw GradleException(
                    "Refusing production release: Android signing certificate must have at least 25 years remaining validity.",
                )
            }
        }
    }
}

tasks.configureEach {
    if (name == "packageRelease" || name == "bundleRelease" || name == "assembleRelease") {
        dependsOn(validateReleaseSigning)
    }
}

android {
    namespace = "com.example.myteam_video_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = androidApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("${androidSigningChannel}Release") {
                storeFile = requireNotNull(releaseKeystore)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("${androidSigningChannel}Release")
            }
            // The task guard above fails closed if external signing inputs are absent.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
