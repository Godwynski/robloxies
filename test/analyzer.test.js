// test/analyzer.test.js
// Automated verification suite for LuauLens Educational Game Architecture Analyzer

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { generateMarkdownReport, generateHtmlDashboard } = require('../tools/offline_analyzer');

console.log('🧪 Starting LuauLens Complete Test Suite...\n');

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

// 1. LuauLens directory structure verification
runTest('LuauLens/ directory and all 7 submodules exist', () => {
    const root = path.join(__dirname, '..', 'LuauLens');
    assert(fs.existsSync(root), 'LuauLens/ directory missing');
    assert(fs.existsSync(path.join(root, 'init.lua')), 'LuauLens/init.lua missing');

    const expectedModules = [
        'Serializer.lua',
        'Utility.lua',
        'CodeAnalyzer.lua',
        'NetworkMonitor.lua',
        'ContentTracker.lua',
        'DocGenerator.lua',
        'UI.lua',
    ];

    for (const mod of expectedModules) {
        const modPath = path.join(root, 'modules', mod);
        assert(fs.existsSync(modPath), `LuauLens/modules/${mod} missing`);
        const content = fs.readFileSync(modPath, 'utf8');
        assert(content.length > 500, `Module ${mod} is unexpectedly small (${content.length} bytes)`);
    }
});

// 2. Specific method verification in LuauLens files
runTest('LuauLens module API method signatures verification', () => {
    const initLua = fs.readFileSync(path.join(__dirname, '..', 'LuauLens', 'init.lua'), 'utf8');
    assert(initLua.includes('function LuauLens:Initialize'), 'Missing LuauLens:Initialize');
    assert(initLua.includes('RightControl') || initLua.includes('KeyCode.RightControl'), 'Missing RightControl keybind in init.lua');

    const serializerLua = fs.readFileSync(path.join(__dirname, '..', 'LuauLens', 'modules', 'Serializer.lua'), 'utf8');
    assert(serializerLua.includes('function Serializer.Serialize'), 'Missing Serializer.Serialize');
    assert(serializerLua.includes('visited'), 'Missing visited cycle protection');
    assert(serializerLua.includes('maxDepth'), 'Missing maxDepth limit');
    assert(serializerLua.includes('Vector3') && serializerLua.includes('CFrame'), 'Missing Vector3/CFrame handling');

    const utilityLua = fs.readFileSync(path.join(__dirname, '..', 'LuauLens', 'modules', 'Utility.lua'), 'utf8');
    assert(utilityLua.includes('function Utility.IsStudio'), 'Missing Utility.IsStudio');
    assert(utilityLua.includes('function Utility.Export'), 'Missing Utility.Export');
    assert(utilityLua.includes('function Utility.GetInstancePath'), 'Missing Utility.GetInstancePath');
    assert(utilityLua.includes('writefile') && utilityLua.includes('setclipboard'), 'Missing writefile / setclipboard in Utility.Export');

    const codeAnalyzerLua = fs.readFileSync(path.join(__dirname, '..', 'LuauLens', 'modules', 'CodeAnalyzer.lua'), 'utf8');
    assert(codeAnalyzerLua.includes('function CodeAnalyzer.ScanGameHierarchy'), 'Missing CodeAnalyzer.ScanGameHierarchy');
    assert(codeAnalyzerLua.includes('Controllers') && codeAnalyzerLua.includes('Services') && codeAnalyzerLua.includes('UI'), 'Missing categorization tables');

    const networkMonitorLua = fs.readFileSync(path.join(__dirname, '..', 'LuauLens', 'modules', 'NetworkMonitor.lua'), 'utf8');
    assert(networkMonitorLua.includes('__namecall'), 'Missing __namecall hook');
    assert(networkMonitorLua.includes('FireServer') && networkMonitorLua.includes('InvokeServer'), 'Missing FireServer/InvokeServer interception');
    assert(networkMonitorLua.includes('function NetworkMonitor.GetNetworkLog'), 'Missing NetworkMonitor.GetNetworkLog');

    const contentTrackerLua = fs.readFileSync(path.join(__dirname, '..', 'LuauLens', 'modules', 'ContentTracker.lua'), 'utf8');
    assert(contentTrackerLua.includes('function ContentTracker.CreateSnapshot'), 'Missing ContentTracker.CreateSnapshot');
    assert(contentTrackerLua.includes('function ContentTracker.CompareSnapshots'), 'Missing ContentTracker.CompareSnapshots');

    const docGeneratorLua = fs.readFileSync(path.join(__dirname, '..', 'LuauLens', 'modules', 'DocGenerator.lua'), 'utf8');
    assert(docGeneratorLua.includes('function DocGenerator.GenerateFullReport'), 'Missing DocGenerator.GenerateFullReport');
    assert(docGeneratorLua.includes('graph TD') && docGeneratorLua.includes('sequenceDiagram'), 'Missing Mermaid diagram syntax');

    const uiLua = fs.readFileSync(path.join(__dirname, '..', 'LuauLens', 'modules', 'UI.lua'), 'utf8');
    assert(uiLua.includes('function UI.CreateDashboard'), 'Missing UI.CreateDashboard');
    assert(uiLua.includes('ScreenGui') && uiLua.includes('Frame'), 'Missing ScreenGui/Frame usage in UI');
});

// 3. Standalone bundle verification
runTest('Standalone bundle dist/LuauLens.bundle.lua exists and is complete', () => {
    const bundlePath = path.join(__dirname, '..', 'dist', 'LuauLens.bundle.lua');
    assert(fs.existsSync(bundlePath), 'dist/LuauLens.bundle.lua does not exist');
    const stats = fs.statSync(bundlePath);
    assert(stats.size > 50000, `Bundle size is unexpectedly small: ${stats.size} bytes`);
    
    const content = fs.readFileSync(bundlePath, 'utf8');
    assert(content.includes('LuauLens'), 'Bundle missing LuauLens identifier');
    assert(content.includes('Serializer'), 'Bundle missing Serializer module');
    assert(content.includes('Utility'), 'Bundle missing Utility module');
    assert(content.includes('CodeAnalyzer'), 'Bundle missing CodeAnalyzer module');
    assert(content.includes('NetworkMonitor'), 'Bundle missing NetworkMonitor module');
    assert(content.includes('ContentTracker'), 'Bundle missing ContentTracker module');
    assert(content.includes('DocGenerator'), 'Bundle missing DocGenerator module');
    assert(content.includes('UI'), 'Bundle missing UI module');
});

// 4. Sample data & diff simulation
runTest('Sample analysis JSON schema & diff engine simulation', () => {
    const jsonPath = path.join(__dirname, '..', 'examples', 'sample_game_analysis.json');
    assert(fs.existsSync(jsonPath), 'sample_game_analysis.json does not exist');
    const raw = fs.readFileSync(jsonPath, 'utf8');
    const data = JSON.parse(raw);

    assert(data.Metadata && data.Metadata.PlaceId, 'Metadata.PlaceId missing');
    assert(data.CodeAnalysis.Categories, 'CodeAnalysis.Categories missing');
    assert(data.NetworkStats && Object.keys(data.NetworkStats).length > 0, 'NetworkStats missing');

    const oldSnap = data.Snapshots[0];
    const newSnap = data.Snapshots[1];
    const addedRemotes = Object.keys(newSnap.Remotes).filter(k => !oldSnap.Remotes[k]);
    assert.strictEqual(addedRemotes.length, 1, 'Expected 1 added remote');
});

// 5. Offline Markdown & HTML Report Generator
runTest('Offline Markdown & HTML Report Generator', () => {
    const jsonPath = path.join(__dirname, '..', 'examples', 'sample_game_analysis.json');
    const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

    const md = generateMarkdownReport(data);
    assert(md.includes('# 🎓 Educational Architecture & Mechanics Report'), 'MD missing header');
    assert(md.includes('```mermaid'), 'MD missing Mermaid diagrams');
    assert(md.includes('CombatController'), 'MD missing CombatController');
    assert(md.includes('Network Remote Contracts'), 'MD missing Remote contracts table');

    const html = generateHtmlDashboard(data, md);
    assert(html.includes('<!DOCTYPE html>'), 'HTML missing doctype');
    assert(html.includes('mermaid.min.js'), 'HTML missing mermaid script import');
});

console.log('\n======================================');
console.log(`Test Results: ${testsPassed} Passed, ${testsFailed} Failed`);
console.log('======================================\n');

if (testsFailed > 0) {
    process.exit(1);
} else {
    process.exit(0);
}
