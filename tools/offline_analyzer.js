// tools/offline_analyzer.js
// Node.js CLI tool to analyze exported LuauLens JSON snapshots and generate educational reports & HTML dashboards

const fs = require('fs');
const path = require('path');

function generateMarkdownReport(data) {
    const lines = [];
    const meta = data.Metadata || {};
    const code = data.CodeAnalysis || {};
    const netStats = data.NetworkStats || {};
    const tags = code.Tags || [];
    const frameworks = code.Frameworks || [];
    const categories = code.Categories || {};

    lines.push(`# 🎓 Educational Architecture & Mechanics Report: ${meta.GameTitle || 'Roblox Experience'}`);
    lines.push(`*Generated from LuauLens Analysis Snapshot | PlaceId: ${meta.PlaceId || 'N/A'} | PlaceVersion: ${meta.PlaceVersion || 'N/A'}*`);
    lines.push('');

    // 1. Architecture
    lines.push('## 1. High-Level Architecture & Frameworks');
    const fwList = frameworks.map(f => `**${f.Name}** (${f.Confidence} confidence)`).join(', ');
    lines.push(`- **Identified Framework(s):** ${fwList || 'Modular Luau / Custom OOP'}`);
    lines.push(`- **Total Client Scripts Analyzed:** ${code.TotalScripts || 0}`);
    lines.push(`- **Network Remote Endpoints:** ${Object.keys(netStats).length}`);
    lines.push('');
    lines.push('### Architecture Flow Diagram');
    lines.push('```mermaid');
    lines.push('graph TD');
    lines.push('    subgraph Client [Client Runtime Environment]');
    lines.push('        UserInput[User Input & Movement]');
    lines.push('        HUD[Player HUD & Views]');
    lines.push('        subgraph Controllers [Client Controllers]');
    if (categories['Controller']) {
        categories['Controller'].forEach((c, idx) => {
            lines.push(`            Ctrl_${idx + 1}["${c.Name}"]`);
        });
    }
    if (categories['Game Mechanic']) {
        categories['Game Mechanic'].forEach((c, idx) => {
            lines.push(`            Mech_${idx + 1}["${c.Name}"]`);
        });
    }
    lines.push('        end');
    lines.push('        UserInput --> Controllers');
    lines.push('        Controllers --> HUD');
    lines.push('    end');
    lines.push('    subgraph ReplicatedStorage [ReplicatedStorage / Network Layer]');
    Object.keys(netStats).forEach((rPath, idx) => {
        const r = netStats[rPath];
        lines.push(`        Rem_${idx + 1}["${r.Name} (${r.System})"]`);
        lines.push(`        Controllers -.->|Network Call| Rem_${idx + 1}`);
    });
    lines.push('    end');
    lines.push('    subgraph Server [Authoritative Server Services]');
    lines.push('        ServerValidation[Sanity Check & Combat Calculator]');
    lines.push('        Database[(Player DataStore / Memory Cache)]');
    Object.keys(netStats).forEach((_, idx) => {
        lines.push(`        Rem_${idx + 1} --> ServerValidation`);
    });
    lines.push('        ServerValidation --> Database');
    lines.push('    end');
    lines.push('```');
    lines.push('');

    // 2. Component Structure
    lines.push('## 2. Client Component Decomposition');
    for (const [catName, scripts] of Object.entries(categories)) {
        lines.push(`### ${catName} (${scripts.length} modules)`);
        lines.push(`*${scripts[0].Description || 'System module'}*`);
        lines.push('');
        lines.push('| Script Name | Class | Location | Educational Role |');
        lines.push('| --- | --- | --- | --- |');
        for (const s of scripts) {
            lines.push(`| \`${s.Name}\` | ${s.ClassName} | \`${s.FullName}\` | ${s.Description || 'N/A'} |`);
        }
        lines.push('');
    }

    // 3. CollectionService Tags
    if (tags.length > 0) {
        lines.push('## 3. Entity-Component System & Tags (CollectionService)');
        lines.push('The experience uses tag-driven component binding for game entities:');
        lines.push('');
        lines.push('| Component Tag | Instances | Class Distribution | Educational Purpose |');
        lines.push('| --- | --- | --- | --- |');
        for (const t of tags) {
            lines.push(`| \`${t.TagName}\` | ${t.Count} | ${t.ClassDistribution || t.SampleClass} | ${t.EducationalNote || 'Entity binding'} |`);
        }
        lines.push('');
    }

    // 4. Remote Contracts & Networking
    lines.push('## 4. Network Remote Contracts & Security Analysis');
    lines.push('| Remote Name | System | Total Calls | Observed Signatures | Security Considerations |');
    lines.push('| --- | --- | --- | --- | --- |');
    for (const [_, stat] of Object.entries(netStats)) {
        const sigs = Object.keys(stat.ArgSignatures || {}).join(' <br> ') || 'void';
        let secNote = 'Verify player ownership and state permission';
        if (stat.System.includes('Combat')) {
            secNote = '⚠️ **Critical:** Server must validate distance, cooldowns, and compute actual damage';
        } else if (stat.System.includes('Economy')) {
            secNote = '🔒 **Strict:** Never accept client prices; validate gold balances server-side';
        } else if (stat.System.includes('Inventory')) {
            secNote = '📦 **Atomic:** Server must handle inventory transactions atomically';
        }
        lines.push(`| \`${stat.Name}\` | ${stat.System} | ${stat.Count} | \`(${sigs})\` | ${secNote} |`);
    }
    lines.push('');

    // 5. Sequence Diagram
    lines.push('## 5. Interaction Sequence Diagram (Client Prediction & Server Authority)');
    lines.push('```mermaid');
    lines.push('sequenceDiagram');
    lines.push('    autonumber');
    lines.push('    actor Player as Local Client');
    lines.push('    participant CombatCtrl as CombatController');
    lines.push('    participant HUD as HUDView');
    lines.push('    participant Remote as AttackRequest');
    lines.push('    participant Server as Server Authoritative Combat Service');
    lines.push('');
    lines.push('    Player->>CombatCtrl: Left Click (Input)');
    lines.push('    activate CombatCtrl');
    lines.push('    Note over CombatCtrl: Client Prediction: Play local animation & sound immediately');
    lines.push('    CombatCtrl->>HUD: Play local crosshair indicator');
    lines.push('    CombatCtrl->>Remote: FireServer("SwordSwing_Light", targetId, hitCoords)');
    lines.push('    deactivate CombatCtrl');
    lines.push('    Remote->>Server: Network Packet Transmission');
    lines.push('    activate Server');
    lines.push('    Note over Server: Server validates:<br/>1. Cooldown timer<br/>2. Spatial distance <= MaxWeaponRange<br/>3. Equipped weapon type');
    lines.push('    alt Sanity Check Passed');
    lines.push('        Server->>Server: Calculate DamageFormula(Weapon, Armor)');
    lines.push('        Server-->>Remote: Broadcast DamageReplication(targetId, finalDamage, isCrit)');
    lines.push('        Remote-->>Player: Confirm Damage & Show Floating Number');
    lines.push('    else Sanity Check Failed (Cheating or Out of Sync)');
    lines.push('        Server-->>Player: Silently discard or trigger reconciliation');
    lines.push('    end');
    lines.push('    deactivate Server');
    lines.push('```');
    lines.push('');

    // 6. Educational Tutorial
    lines.push('## 6. Generated Tutorial: Implementing Secure Networking in Luau');
    lines.push('```lua');
    lines.push('-- [TUTORIAL] Authoritative Combat Remote Handler');
    lines.push('local ReplicatedStorage = game:GetService("ReplicatedStorage")');
    lines.push('local AttackRemote = ReplicatedStorage:WaitForChild("AttackRequest")');
    lines.push('');
    lines.push('local MAX_ALLOWED_DISTANCE = 15 -- Studs');
    lines.push('local COOLDOWN_SECONDS = 0.6');
    lines.push('local lastAttackTimes = {}');
    lines.push('');
    lines.push('AttackRemote.OnServerEvent:Connect(function(player, attackType, targetCharacterId, hitPosition)');
    lines.push('    local character = player.Character');
    lines.push('    if not character or not character:FindFirstChild("Humanoid") or character.Humanoid.Health <= 0 then');
    lines.push('        return -- Dead or invalid character cannot initiate attacks');
    lines.push('    end');
    lines.push('');
    lines.push('    -- 1. Anti-spam & Cooldown check');
    lines.push('    local now = os.clock()');
    lines.push('    local lastTime = lastAttackTimes[player] or 0');
    lines.push('    if (now - lastTime) < COOLDOWN_SECONDS then return end');
    lines.push('    lastAttackTimes[player] = now');
    lines.push('');
    lines.push('    -- 2. Spatial distance check');
    lines.push('    local targetCharacter = workspace:FindFirstChild(tostring(targetCharacterId))');
    lines.push('    if not targetCharacter or not targetCharacter:FindFirstChild("HumanoidRootPart") then return end');
    lines.push('');
    lines.push('    local distance = (character.HumanoidRootPart.Position - targetCharacter.HumanoidRootPart.Position).Magnitude');
    lines.push('    if distance > MAX_ALLOWED_DISTANCE then return end');
    lines.push('');
    lines.push('    -- 3. Compute authentic damage on server');
    lines.push('    local damage = 35');
    lines.push('    targetCharacter.Humanoid:TakeDamage(damage)');
    lines.push('end)');
    lines.push('```');

    return lines.join('\n');
}

function generateHtmlDashboard(data, markdownContent) {
    const meta = data.Metadata || {};
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LuauLens Report: ${meta.GameTitle || 'Roblox Experience'}</title>
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <style>
        :root {
            --bg: #0d1117;
            --sidebar: #161b22;
            --card: #1f242c;
            --border: #30363d;
            --accent: #6366f1;
            --accent-light: #818cf8;
            --text: #f0f6fc;
            --text-muted: #8b949e;
            --success: #238636;
            --code-bg: #0b0e14;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
        body { background-color: var(--bg); color: var(--text); line-height: 1.6; }
        header { background-color: var(--sidebar); border-bottom: 1px solid var(--border); padding: 18px 32px; display: flex; justify-content: space-between; align-items: center; }
        header h1 { font-size: 20px; font-weight: 700; color: var(--text); }
        .badge { background-color: var(--card); border: 1px solid var(--border); padding: 4px 10px; border-radius: 6px; font-size: 12px; color: var(--accent-light); }
        .container { max-width: 1200px; margin: 30px auto; padding: 0 20px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; margin-bottom: 30px; }
        .card { background-color: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 18px; }
        .card .title { font-size: 12px; color: var(--text-muted); text-transform: uppercase; font-weight: 600; margin-bottom: 6px; }
        .card .value { font-size: 24px; font-weight: 700; color: var(--text); }
        .section { background-color: var(--sidebar); border: 1px solid var(--border); border-radius: 8px; padding: 24px; margin-bottom: 24px; }
        .section h2 { font-size: 18px; font-weight: 700; margin-bottom: 16px; border-bottom: 1px solid var(--border); padding-bottom: 8px; }
        table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 13px; }
        th, td { text-align: left; padding: 10px 14px; border-bottom: 1px solid var(--border); }
        th { background-color: var(--card); color: var(--text-muted); font-weight: 600; }
        tr:hover { background-color: rgba(255,255,255,0.02); }
        pre { background-color: var(--code-bg); padding: 16px; border-radius: 6px; overflow-x: auto; font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: 12px; border: 1px solid var(--border); }
        .mermaid { background-color: var(--code-bg); padding: 20px; border-radius: 8px; border: 1px solid var(--border); overflow-x: auto; }
    </style>
</head>
<body>
    <header>
        <div>
            <h1>🔍 LuauLens Architecture & Mechanics Report</h1>
            <p style="color: var(--text-muted); font-size: 13px;">Experience: ${meta.GameTitle || 'Roblox Experience'} (PlaceId: ${meta.PlaceId || 'N/A'})</p>
        </div>
        <div class="badge">Engine PlaceVersion ${meta.PlaceVersion || '1'}</div>
    </header>

    <div class="container">
        <div class="grid">
            <div class="card">
                <div class="title">Client Scripts</div>
                <div class="value">${data.CodeAnalysis?.TotalScripts || 0}</div>
            </div>
            <div class="card">
                <div class="title">Active Remotes</div>
                <div class="value">${Object.keys(data.NetworkStats || {}).length}</div>
            </div>
            <div class="card">
                <div class="title">Component Tags</div>
                <div class="value">${data.CodeAnalysis?.Tags?.length || 0}</div>
            </div>
            <div class="card">
                <div class="title">Architecture Framework</div>
                <div class="value" style="font-size: 18px;">${data.CodeAnalysis?.Frameworks?.[0]?.Name || 'Modular Luau'}</div>
            </div>
        </div>

        <div class="section">
            <h2>System Architecture Map</h2>
            <div class="mermaid">
graph TD
    subgraph Client [Client Runtime]
        Input[User Input & Controls] --> Controllers[Controllers & Mechanics]
        Controllers --> UI[HUD & Views]
    end
    subgraph Network [Replicated Network Layer]
        Controllers -.->|FireServer / InvokeServer| Remotes[RemoteEvents & RemoteFunctions]
    end
    subgraph Server [Authoritative Server]
        Remotes --> Logic[Sanity Validation & Combat Formulas]
        Logic --> Store[(PlayerData / DataStores)]
    end
            </div>
        </div>

        <div class="section">
            <h2>Network Remote Contracts</h2>
            <table>
                <thead>
                    <tr>
                        <th>Remote Name</th>
                        <th>System</th>
                        <th>Observed Signature</th>
                        <th>Call Count</th>
                    </tr>
                </thead>
                <tbody>
                    ${Object.entries(data.NetworkStats || {}).map(([_, s]) => `
                    <tr>
                        <td><strong>${s.Name}</strong></td>
                        <td><span class="badge">${s.System}</span></td>
                        <td><code>(${Object.keys(s.ArgSignatures || {}).join(', ') || 'void'})</code></td>
                        <td>${s.Count}</td>
                    </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    </div>

    <script>
        mermaid.initialize({ startOnLoad: true, theme: 'dark' });
    </script>
</body>
</html>`;
}

function main() {
    const args = process.argv.slice(2);
    let inputFile = path.join(__dirname, '..', 'examples', 'sample_game_analysis.json');
    let outMd = path.join(__dirname, '..', 'examples', 'sample_generated_report.md');
    let outHtml = path.join(__dirname, '..', 'dist', 'report.html');

    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--input' && args[i + 1]) inputFile = args[++i];
        else if (args[i] === '--output-md' && args[i + 1]) outMd = args[++i];
        else if (args[i] === '--output-html' && args[i + 1]) outHtml = args[++i];
        else if (!args[i].startsWith('--')) inputFile = args[i];
    }

    console.log(`📖 Reading analysis file: ${inputFile}`);
    if (!fs.existsSync(inputFile)) {
        console.error(`❌ Input file not found: ${inputFile}`);
        process.exit(1);
    }

    const raw = fs.readFileSync(inputFile, 'utf8');
    const data = JSON.parse(raw);

    const mdReport = generateMarkdownReport(data);
    fs.writeFileSync(outMd, mdReport, 'utf8');
    console.log(`✅ Markdown report written to: ${outMd}`);

    const htmlReport = generateHtmlDashboard(data, mdReport);
    fs.writeFileSync(outHtml, htmlReport, 'utf8');
    console.log(`✅ HTML dashboard written to: ${outHtml}`);
}

if (require.main === module) {
    main();
} else {
    module.exports = {
        generateMarkdownReport,
        generateHtmlDashboard,
    };
}
