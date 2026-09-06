// tools/build_analyzer.js
// Bundles the LuauLens Analyzer suite into a single-file executable dist/analyzer.bundle.lua

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '..');
const ANALYZER_DIR = path.join(ROOT_DIR, 'analyzer');
const MODULES_DIR = path.join(ANALYZER_DIR, 'modules');
const DIST_DIR = path.join(ROOT_DIR, 'dist');
const OUTPUT_FILE = path.join(DIST_DIR, 'analyzer.bundle.lua');

function getModuleFiles(dir) {
    if (!fs.existsSync(dir)) return [];
    return fs.readdirSync(dir)
        .filter(f => f.endsWith('.lua'))
        .map(f => path.join(dir, f));
}

function bundle() {
    console.log('🚀 Bundling LuauLens Educational Game Architecture Analyzer...');

    if (!fs.existsSync(DIST_DIR)) {
        fs.mkdirSync(DIST_DIR, { recursive: true });
    }

    const moduleFiles = getModuleFiles(MODULES_DIR);
    const moduleDefs = [];

    for (const filePath of moduleFiles) {
        const baseName = path.basename(filePath, '.lua');
        const modKey = `analyzer.modules.${baseName}`;
        let content = fs.readFileSync(filePath, 'utf8');

        // Replace require calls with __require
        content = content.replace(/require\((['"])([^'"]+)\1\)/g, '__require("$2")');

        console.log(`  📦 Packaging module: ${modKey} (${filePath})`);
        moduleDefs.push(`
__modules["${modKey}"] = {
    loaded = false,
    cached = nil,
    fn = function(__require)
${content}
    end
};
`);
    }

    let initContent = fs.readFileSync(path.join(ANALYZER_DIR, 'init.lua'), 'utf8');
    initContent = initContent.replace(/require\((['"])([^'"]+)\1\)/g, '__require("$2")');

    const bundleCode = `--[[
    ========================================================================
    🔍 LuauLens — Educational Roblox Game Architecture & Mechanics Analyzer
    Version: 1.0.0
    Single-file Standalone Bundle for Roblox Experiences & Studio
    ========================================================================
]]

local __modules = {}
local function __require(name)
    local mod = __modules[name]
    if not mod then
        error("[LuauLens Loader] Module not found: " .. tostring(name))
    end
    if not mod.loaded then
        mod.cached = mod.fn(__require)
        mod.loaded = true
    end
    return mod.cached
end

-- Embedded Module Registrations
${moduleDefs.join('\n')}

-- Main Runtime Initialization
return (function(__require)
${initContent}
end)(__require)
`;

    fs.writeFileSync(OUTPUT_FILE, bundleCode, 'utf8');
    const stats = fs.statSync(OUTPUT_FILE);
    console.log(`\n✅ Successfully created standalone bundle: ${OUTPUT_FILE}`);
    console.log(`📊 Bundle Size: ${(stats.size / 1024).toFixed(2)} KB\n`);
}

bundle();
