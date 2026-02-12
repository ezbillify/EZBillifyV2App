const fs = require('fs');
const { execSync } = require('child_process');
const https = require('https');
const path = require('path');

// Configuration
const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const MODEL = 'llama-3.1-8b-instant';

// 1. Load Environment Variables
function loadEnv() {
    const envPath = path.join(__dirname, '..', '.env');
    if (fs.existsSync(envPath)) {
        const content = fs.readFileSync(envPath, 'utf8');
        content.split('\n').forEach(line => {
            const parts = line.split('=');
            if (parts.length >= 2 && !line.startsWith('#')) {
                const key = parts[0].trim();
                const value = parts.slice(1).join('=').trim().replace(/(^"|"$)/g, '');
                if (!process.env[key]) process.env[key] = value;
            }
        });
    }
}

loadEnv();
const API_KEY = process.env.GROQ_API_KEY;

if (!API_KEY) {
    console.error("❌ Error: GROQ_API_KEY not found in .env or environment.");
    process.exit(1);
}

// 2. Get Git Diff
try {
    console.log("📦 Staging changes...");
    execSync('git add .', { stdio: 'inherit' });
    const diff = execSync('git diff --cached', { encoding: 'utf8' });

    if (!diff.trim()) {
        console.log("✨ No changes to commit.");
        process.exit(0);
    }

    // 3. Analyze with Groq
    console.log("🤖 Analyzing changes with Groq...");

    const prompt = `
    You are a precise version control assistant. Analyze the following git diff and generate a clean, conventional commit message.
    Also, determine if the changes warrant a 'minor' version bump (new modules, major features) or a 'patch' version bump (bug fixes, styling, small tweaks).
    
    Rules:
    - If new features/modules are added, bump_type = 'minor'.
    - If only bug fixes/styling/refactoring, bump_type = 'patch'.
    - Return ONLY valid JSON in this format: { "commit_message": "string", "bump_type": "minor" | "patch" }
    
    Diff:
    ${diff.substring(0, 10000)} // Truncate to avoid token limits
  `;

    const reqBody = JSON.stringify({
        model: MODEL,
        messages: [
            { role: "system", content: "You are a helpful coding assistant. Output only valid JSON." },
            { role: "user", content: prompt }
        ],
        temperature: 0.1,
        response_format: { type: "json_object" }
    });

    const req = https.request(GROQ_API_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${API_KEY}`
        }
    }, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => {
            if (res.statusCode !== 200) {
                console.error(`❌ Groq API Error: ${res.statusCode} ${data}`);
                process.exit(1);
            }

            try {
                const result = JSON.parse(data);
                const aiResponse = JSON.parse(result.choices[0].message.content);

                console.log(`📝 Commit Message: ${aiResponse.commit_message}`);
                console.log(`📈 Bump Type: ${aiResponse.bump_type}`);

                bumpVersionAndCommit(aiResponse.commit_message, aiResponse.bump_type);
            } catch (e) {
                console.error("❌ Error parsing AI response:", e);
                process.exit(1);
            }
        });
    });

    req.on('error', (e) => {
        console.error("❌ Request Error:", e);
        process.exit(1);
    });

    req.write(reqBody);
    req.end();

} catch (e) {
    console.error("❌ Error:", e.message);
    process.exit(1);
}

function bumpVersionAndCommit(message, bumpType) {
    const pubspecPath = path.join(__dirname, '..', 'pubspec.yaml');
    let pubspec = fs.readFileSync(pubspecPath, 'utf8');

    // Regex to find version: 1.2.3+4
    const versionRegex = /^version:\s+(\d+)\.(\d+)\.(\d+)\+(\d+)$/m;
    const match = pubspec.match(versionRegex);

    if (!match) {
        console.error("❌ Could not find valid version in pubspec.yaml");
        process.exit(1);
    }

    let [full, major, minor, patch, build] = match;
    major = parseInt(major);
    minor = parseInt(minor);
    patch = parseInt(patch);
    build = parseInt(build);

    if (bumpType === 'minor') {
        minor += 1;
        patch = 0; // Standard semantic versioning
    } else {
        patch += 1;
    }
    build += 1; // Always bump build number

    const newVersion = `${major}.${minor}.${patch}+${build}`;
    console.log(`🚀 Bumping version: ${match[0].replace('version: ', '')} -> ${newVersion}`);

    // Replace in file
    const newPubspec = pubspec.replace(versionRegex, `version: ${newVersion}`);
    fs.writeFileSync(pubspecPath, newPubspec);

    // Commit and Push
    try {
        execSync('git add pubspec.yaml', { stdio: 'inherit' });
        execSync(`git commit -m "${message}"`, { stdio: 'inherit' });
        console.log("🔄 Pushing to remote...");
        execSync('git push', { stdio: 'inherit' });
        console.log("✅ Done! Changes pushed and version bumped.");
    } catch (e) {
        console.error("❌ Git Error:", e.message);
        process.exit(1);
    }
}
