// test/analyzer.test.js
// Automated verification suite for LuauLens Educational Game Architecture Analyzer

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { generateMarkdownReport, generateHtmlDashboard } = require('../tools/offline_analyzer');

console.log('🧪 Starting LuauLens Test Suite...\n');

let testsPassed = 0;
let testsFailed = 0;

function runTest(name, fn) {
    try {
        fn();
        console.log(`  ✅ [PASS] ${name}`);
        testsPassed++;
    } catch (err) {
        console.error(`  ❌ [FAIL] ${name}`);
        console.error(`     Error: ${err.message}\n`);
        testsFailed++;
    }
}

// 1. Bundle verification
runTest('Standalone bundle dist/analyzer.bundle.lua exists and is non-empty', () => {
    const bundlePath = path.join(__dirname, '..', 'dist', 'analyzer.bundle.lua');
    assert(fs.existsSync(bundlePath), 'dist/analyzer.bundle.lua does not exist');
    const stats = fs.statSync(bundlePath);
    assert(stats.size > 20000, `Bundle size is unexpectedly small: ${stats.size} bytes`);
    
    const content = fs.readFileSync(bundlePath, 'utf8');
    assert(content.includes('LuauLens'), 'Bundle missing LuauLens identifier');
    assert(content.includes('__modules["analyzer.modules.CodeAnalyzer"]'), 'Bundle missing CodeAnalyzer module');
    assert(content.includes('__modules["analyzer.modules.NetworkMonitor"]'), 'Bundle missing NetworkMonitor module');
    assert(content.includes('__modules["analyzer.modules.ContentTracker"]'), 'Bundle missing ContentTracker module');
    assert(content.includes('__modules["analyzer.modules.DocGenerator"]'), 'Bundle missing DocGenerator module');
    assert(content.includes('__modules["analyzer.modules.UI"]'), 'Bundle missing UI module');
});

// 2. Sample data verification
runTest('Sample analysis JSON schema validation', () => {
    const jsonPath = path.join(__dirname, '..', 'examples', 'sample_game_analysis.json');
    assert(fs.existsSync(jsonPath), 'sample_game_analysis.json does not exist');
    const raw = fs.readFileSync(jsonPath, 'utf8');
    const data = JSON.parse(raw);

    assert(data.Metadata && data.Metadata.PlaceId, 'Metadata.PlaceId missing');
    assert(data.CodeAnalysis && data.CodeAnalysis.Scripts === undefined, 'Expected structured object');
    assert(data.CodeAnalysis.Categories, 'CodeAnalysis.Categories missing');
    assert(data.CodeAnalysis.Frameworks && data.CodeAnalysis.Frameworks.length > 0, 'CodeAnalysis.Frameworks missing');
    assert(data.NetworkStats && Object.keys(data.NetworkStats).length > 0, 'NetworkStats missing');
    assert(data.NetworkTrafficSample && data.NetworkTrafficSample.length > 0, 'NetworkTrafficSample missing');
    assert(data.Snapshots && data.Snapshots.length >= 2, 'Snapshots missing or insufficient');
});

// 3. Diff Engine Simulation
runTest('Content tracking diff engine simulation', () => {
    const jsonPath = path.join(__dirname, '..', 'examples', 'sample_game_analysis.json');
    const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const oldSnap = data.Snapshots[0];
    const newSnap = data.Snapshots[1];

    const addedRemotes = [];
    for (const [path, r] of Object.entries(newSnap.Remotes)) {
        if (!oldSnap.Remotes[path]) addedRemotes.push(r);
    }
    assert.strictEqual(addedRemotes.length, 1, 'Expected 1 newly added Remote');
    assert.strictEqual(addedRemotes[0].Name, 'SkillCast', 'Expected added remote to be SkillCast');

    const addedAssets = [];
    for (const [id, a] of Object.entries(newSnap.Assets)) {
        if (!oldSnap.Assets[id]) addedAssets.push(a);
    }
    assert.strictEqual(addedAssets.length, 2, 'Expected 2 newly added Assets (BossRoar, SkillCastAnim)');
});

// 4. Offline Report Generation
runTest('Offline Markdown & HTML Report Generator', () => {
    const jsonPath = path.join(__dirname, '..', 'examples', 'sample_game_analysis.json');
    const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

    const md = generateMarkdownReport(data);
    assert(md.includes('# 🎓 Educational Architecture & Mechanics Report'), 'MD missing header');
    assert(md.includes('```mermaid'), 'MD missing Mermaid diagrams');
    assert(md.includes('CombatController'), 'MD missing CombatController');
    assert(md.includes('Network Remote Contracts'), 'MD missing Remote contracts table');
    assert(md.includes('Authoritative Combat Remote Handler'), 'MD missing tutorial code block');

    const html = generateHtmlDashboard(data, md);
    assert(html.includes('<!DOCTYPE html>'), 'HTML missing doctype');
    assert(html.includes('mermaid.min.js'), 'HTML missing mermaid script import');
    assert(html.includes('Realm of Blades'), 'HTML missing game title');
});

// 5. Documentation completeness
runTest('Educational Guide document completeness', () => {
    const guidePath = path.join(__dirname, '..', 'docs', 'EDUCATIONAL_GUIDE.md');
    assert(fs.existsSync(guidePath), 'EDUCATIONAL_GUIDE.md does not exist');
    const content = fs.readFileSync(guidePath, 'utf8');
    assert(content.includes('Model-View-Controller'), 'Guide missing MVC pattern');
    assert(content.includes('CollectionService'), 'Guide missing CollectionService explanation');
    assert(content.includes('Never Trust the Client'), 'Guide missing network security section');
    assert(content.includes('RemoteEvent vs RemoteFunction'), 'Guide missing RemoteEvent vs RemoteFunction comparison');
});

console.log('\n======================================');
console.log(`Test Results: ${testsPassed} Passed, ${testsFailed} Failed`);
console.log('======================================\n');

if (testsFailed > 0) {
    process.exit(1);
} else {
    process.exit(0);
}
