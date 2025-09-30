// AUTO-GENERATED from audit-activities.merged.json
// Run `npm run sync:activities` to regenerate this file.
export type Activity = { id:string; name:string; description:string; category:string };

// Default: CopilotInteraction Only (for basic Copilot usage reports)
export const RELEVANT_ACTIVITIES: Activity[] = [
  { id:'CopilotInteraction', name:'Copilot Interaction', description:'Copilot AI copilot interaction', category:'Copilot & AI' }
];

// Curated: Comprehensive Copilot & Microsoft 365 activities (40 activities)
export const CURATED_ACTIVITIES: Activity[] = [
  { id:'CopilotInteraction', name:'Copilot Interaction', description:'Copilot AI copilot interaction', category:'Copilot & AI' },
  { id:'CreatePlugin', name:'Create Plugin', description:'Copilot AI create plugin', category:'Copilot & AI' },
  { id:'EnablePlugin', name:'Enable Plugin', description:'Copilot AI enable plugin', category:'Copilot & AI' },
  { id:'DisableCopilotPlugin', name:'Disable Copilot Plugin', description:'Copilot AI disable copilot plugin', category:'Copilot & AI' },
  { id:'DeletePlugin', name:'Delete Plugin', description:'Copilot AI delete plugin', category:'Copilot & AI' },
  { id:'UpdatePlugin', name:'Update Plugin', description:'Copilot AI update plugin', category:'Copilot & AI' },
  { id:'CreatePromptBook', name:'Create Prompt Book', description:'Copilot AI create prompt book', category:'Copilot & AI' },
  { id:'EnablePromptBook', name:'Enable Prompt Book', description:'Copilot AI enable prompt book', category:'Copilot & AI' },
  { id:'DisablePromptBook', name:'Disable Prompt Book', description:'Copilot AI disable prompt book', category:'Copilot & AI' },
  { id:'DeletePromptBook', name:'Delete Prompt Book', description:'Copilot AI delete prompt book', category:'Copilot & AI' },
  { id:'UpdatePromptBook', name:'Update Prompt Book', description:'Copilot AI update prompt book', category:'Copilot & AI' },
  { id:'UpdateTenantSettings', name:'Update Tenant Settings', description:'Update Tenant Settings', category:'Copilot & AI' },
  { id:'ScheduledPromptCreated', name:'Scheduled Prompt Created', description:'Copilot AI scheduled prompt created', category:'Copilot & AI' },
  { id:'ScheduledPromptDeleted', name:'Scheduled Prompt Deleted', description:'Copilot AI scheduled prompt deleted', category:'Copilot & AI' },
  { id:'ScheduledPromptExecute', name:'Scheduled Prompt Execute', description:'Copilot AI scheduled prompt execute', category:'Copilot & AI' },
  { id:'MessageSent', name:'Message Sent', description:'Message sent', category:'Teams / Meetings / Chat / Channels' },
  { id:'MessageRead', name:'Message Read', description:'Message read', category:'Teams / Meetings / Chat / Channels' },
  { id:'MeetingDetail', name:'Meeting Detail', description:'Teams meeting detail', category:'Teams / Meetings / Chat / Channels' },
  { id:'MeetingParticipantDetail', name:'Meeting Participant Detail', description:'Teams meeting participant detail', category:'Teams / Meetings / Chat / Channels' },
  { id:'AINotesUpdate', name:'A I Notes Update', description:'A I Notes Update', category:'Teams / Meetings / Chat / Channels' },
  { id:'LiveNotesUpdate', name:'Live Notes Update', description:'Live Notes Update', category:'Teams / Meetings / Chat / Channels' },
  { id:'TeamsSessionStarted', name:'Teams Session Started', description:'Teams Session Started', category:'Teams / Meetings / Chat / Channels' },
  { id:'FileAccessed', name:'File Accessed', description:'File accessed', category:'SharePoint / OneDrive / Files' },
  { id:'FileAccessedExtended', name:'File Accessed Extended', description:'File accessed extended', category:'SharePoint / OneDrive / Files' },
  { id:'FilePreviewed', name:'File Previewed', description:'File previewed', category:'SharePoint / OneDrive / Files' },
  { id:'FileDownloaded', name:'File Downloaded', description:'File downloaded', category:'SharePoint / OneDrive / Files' },
  { id:'FileUploaded', name:'File Uploaded', description:'File uploaded', category:'SharePoint / OneDrive / Files' },
  { id:'FileModified', name:'File Modified', description:'File modified', category:'SharePoint / OneDrive / Files' },
  { id:'PageViewed', name:'Page Viewed', description:'Page Viewed', category:'SharePoint / OneDrive / Files' },
  { id:'SearchQueryPerformed', name:'Search Query Performed', description:'Search Query Performed', category:'Other / General' },
  { id:'MailItemsAccessed', name:'Mail Items Accessed', description:'Email accessed', category:'Exchange / Outlook / Mailbox' },
  { id:'Send', name:'Send', description:'Send', category:'Exchange / Outlook / Mailbox' },
  { id:'MailboxLogin', name:'Mailbox Login', description:'Email mailbox login', category:'Exchange / Outlook / Mailbox' },
  { id:'FileSensitivityLabelApplied', name:'File Sensitivity Label Applied', description:'File sensitivity label applied', category:'Security & Compliance' },
  { id:'FileSensitivityLabelChanged', name:'File Sensitivity Label Changed', description:'File sensitivity label changed', category:'Security & Compliance' },
  { id:'FileSensitivityLabelRemoved', name:'File Sensitivity Label Removed', description:'File sensitivity label removed', category:'Security & Compliance' },
  { id:'SharingSet', name:'Sharing Set', description:'Sharing Set', category:'SharePoint / OneDrive / Files' },
  { id:'SharingInvitationAccepted', name:'Sharing Invitation Accepted', description:'Sharing Invitation Accepted', category:'SharePoint / OneDrive / Files' },
  { id:'SecureLinkCreated', name:'Secure Link Created', description:'Secure Link Created', category:'SharePoint / OneDrive / Files' },
  { id:'SecureLinkUsed', name:'Secure Link Used', description:'Secure Link Used', category:'SharePoint / OneDrive / Files' }
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
