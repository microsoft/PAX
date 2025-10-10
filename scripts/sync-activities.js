#!/usr/bin/env node

/**
 * Sync script to update activities.ts from audit-activities.merged.json
 * Uses the 'curated' preset (40 activities) as the default RELEVANT_ACTIVITIES
 */

import fs from 'fs';
import path from 'path';

const AUDIT_DATA_PATH = './scripts/audit-activities.merged.json';
const ACTIVITIES_OUTPUT_PATH = './src/lib/activities.ts';

// Activity ID to category mapping - manual mapping for known activities
const ACTIVITY_CATEGORIES = {
  // Copilot & AI
  'CopilotInteraction': 'Copilot & AI',
  'CreatePlugin': 'Copilot & AI', 
  'EnablePlugin': 'Copilot & AI',
  'DisableCopilotPlugin': 'Copilot & AI',
  'DeletePlugin': 'Copilot & AI',
  'UpdatePlugin': 'Copilot & AI',
  'CreatePromptBook': 'Copilot & AI',
  'EnablePromptBook': 'Copilot & AI',
  'DisablePromptBook': 'Copilot & AI',
  'DeletePromptBook': 'Copilot & AI',
  'UpdatePromptBook': 'Copilot & AI',
  'UpdateTenantSettings': 'Copilot & AI',
  'ScheduledPromptCreated': 'Copilot & AI',
  'ScheduledPromptDeleted': 'Copilot & AI',
  'ScheduledPromptExecute': 'Copilot & AI',
  
  // Teams / Meetings / Chat / Channels
  'MessageSent': 'Teams / Meetings / Chat / Channels',
  'MessageRead': 'Teams / Meetings / Chat / Channels',
  'MeetingDetail': 'Teams / Meetings / Chat / Channels',
  'MeetingParticipantDetail': 'Teams / Meetings / Chat / Channels',
  'AINotesUpdate': 'Teams / Meetings / Chat / Channels',
  'LiveNotesUpdate': 'Teams / Meetings / Chat / Channels',
  'TeamsSessionStarted': 'Teams / Meetings / Chat / Channels',
  
  // SharePoint / OneDrive / Files
  'FileAccessed': 'SharePoint / OneDrive / Files',
  'FileAccessedExtended': 'SharePoint / OneDrive / Files',
  'FilePreviewed': 'SharePoint / OneDrive / Files',
  'FileDownloaded': 'SharePoint / OneDrive / Files',
  'FileUploaded': 'SharePoint / OneDrive / Files',
  'FileModified': 'SharePoint / OneDrive / Files',
  'PageViewed': 'SharePoint / OneDrive / Files',
  'FileSensitivityLabelApplied': 'Security & Compliance',
  'FileSensitivityLabelChanged': 'Security & Compliance',
  'FileSensitivityLabelRemoved': 'Security & Compliance',
  'SharingSet': 'SharePoint / OneDrive / Files',
  'SharingInvitationAccepted': 'SharePoint / OneDrive / Files',
  'SecureLinkCreated': 'SharePoint / OneDrive / Files',
  'SecureLinkUsed': 'SharePoint / OneDrive / Files',
  
  // Exchange / Outlook / Mailbox
  'MailItemsAccessed': 'Exchange / Outlook / Mailbox',
  'Send': 'Exchange / Outlook / Mailbox',
  'MailboxLogin': 'Exchange / Outlook / Mailbox',
  
  // Other / General
  'SearchQueryPerformed': 'Other / General'
};

// Generate human-readable names and descriptions
function generateActivityMetadata(id) {
  const name = id.replace(/([A-Z])/g, ' $1').trim();
  const category = ACTIVITY_CATEGORIES[id] || 'Other / General';
  
  // Generate descriptions based on activity patterns
  let description = '';
  if (id.includes('Copilot') || id.includes('Plugin') || id.includes('Prompt')) {
    description = `Copilot AI ${name.toLowerCase()}`;
  } else if (id.includes('File')) {
    description = `File ${name.toLowerCase().replace('file ', '')}`;
  } else if (id.includes('Meeting')) {
    description = `Teams meeting ${name.toLowerCase().replace('meeting ', '')}`;
  } else if (id.includes('Message')) {
    description = `Message ${name.toLowerCase().replace('message ', '')}`;
  } else if (id.includes('Mail')) {
    description = `Email ${name.toLowerCase().replace('mail ', '').replace('items ', '')}`;
  } else {
    description = name;
  }
  
  return { name, description, category };
}

function main() {
  try {
    console.log('Reading audit activities data...');
    const auditData = JSON.parse(fs.readFileSync(AUDIT_DATA_PATH, 'utf8'));
    
    if (!auditData.presets) {
      throw new Error('Presets not found in audit data');
    }
    
    // Create CopilotInteraction-only preset as default
    const copilotOnlyActivities = ['CopilotInteraction'];
    const curatedActivities = auditData.presets.curated;
    const allActivities = auditData.presets.all;
    
    console.log(`Found ${copilotOnlyActivities.length} CopilotInteraction-only activities`);
    console.log(`Found ${curatedActivities.length} curated activities`);
    console.log(`Found ${allActivities.length} total activities`);
    
    // Generate activity objects for default (CopilotInteraction only)
    const defaultActivities = copilotOnlyActivities.map(id => {
      const { name, description, category } = generateActivityMetadata(id);
      return { id, name, description, category };
    });
    
    // Generate activity objects for curated
    const curatedActivityObjects = curatedActivities.map(id => {
      const { name, description, category } = generateActivityMetadata(id);
      return { id, name, description, category };
    });
    
    // Use CopilotInteraction-only as the default RELEVANT_ACTIVITIES
    const activities = defaultActivities;
    
    // Group by categories for validation
    const categoryCounts = {};
    activities.forEach(act => {
      categoryCounts[act.category] = (categoryCounts[act.category] || 0) + 1;
    });
    
    console.log('Default activities by category:');
    Object.entries(categoryCounts).forEach(([cat, count]) => {
      console.log(`  ${cat}: ${count}`);
    });
    
    // Generate TypeScript content
    const content = `// AUTO-GENERATED from audit-activities.merged.json
// Run \`npm run sync:activities\` to regenerate this file.
export type Activity = { id:string; name:string; description:string; category:string };

// Default: CopilotInteraction Only (for basic Copilot usage reports)
export const RELEVANT_ACTIVITIES: Activity[] = [
${activities.map(act => 
  `  { id:'${act.id}', name:'${act.name}', description:'${act.description}', category:'${act.category}' }`
).join(',\n')}
];

// Curated: Comprehensive Copilot & Microsoft 365 activities (40 activities)
export const CURATED_ACTIVITIES: Activity[] = [
${curatedActivityObjects.map(act => 
  `  { id:'${act.id}', name:'${act.name}', description:'${act.description}', category:'${act.category}' }`
).join(',\n')}
];

export const ALL_ACTIVITIES: Record<string, Activity[]> = {
  'Copilot & AI': RELEVANT_ACTIVITIES.filter(a=>a.category==='Copilot & AI'),
  'Exchange / Outlook / Mailbox': RELEVANT_ACTIVITIES.filter(a=>a.category==='Exchange / Outlook / Mailbox'),
  'Teams / Meetings / Chat / Channels': RELEVANT_ACTIVITIES.filter(a=>a.category==='Teams / Meetings / Chat / Channels'),
  'SharePoint / OneDrive / Files': RELEVANT_ACTIVITIES.filter(a=>a.category==='SharePoint / OneDrive / Files'),
  'Azure AD / Identity / Sign-ins': RELEVANT_ACTIVITIES.filter(a=>a.category==='Azure AD / Identity / Sign-ins'),
  'Security & Compliance': RELEVANT_ACTIVITIES.filter(a=>a.category==='Security & Compliance'),
  'Other / General': RELEVANT_ACTIVITIES.filter(a=>a.category==='Other / General')
};
`;
    
    console.log(`Writing to ${ACTIVITIES_OUTPUT_PATH}...`);
    fs.writeFileSync(ACTIVITIES_OUTPUT_PATH, content);
    
    console.log('✅ Successfully synced activities!');
    console.log(`📊 Generated ${activities.length} default activities (CopilotInteraction only)`);
    console.log(`📋 Generated ${curatedActivityObjects.length} curated activities available`);
    
  } catch (error) {
    console.error('❌ Error syncing activities:', error.message);
    process.exit(1);
  }
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  main();
}

