// AUTO-GENERATED placeholder. Run `npm run sync:activities` to populate.
export type Activity = { id:string; name:string; description:string; category:string };
export const RELEVANT_ACTIVITIES: Activity[] = [
  { id:'CopilotChatAccessed', name:'CopilotChatAccessed', description:'User accessed Copilot chat', category:'Copilot & AI' },
  { id:'CopilotInteractionSummaryViewed', name:'CopilotInteractionSummaryViewed', description:'User viewed Copilot interaction summary', category:'Copilot & AI' },
  { id:'CopilotPromptUsed', name:'CopilotPromptUsed', description:'User submitted a prompt to Copilot', category:'Copilot & AI' },
  { id:'CopilotQuerySentToBing', name:'CopilotQuerySentToBing', description:'Copilot sent a query to Bing', category:'Copilot & AI' },
  { id:'ChannelMessageSent', name:'ChannelMessageSent', description:'Message sent in a Teams channel', category:'Teams / Meetings / Chat / Channels' },
  { id:'DocumentDownloaded', name:'DocumentDownloaded', description:'Document downloaded (SharePoint, OneDrive)', category:'SharePoint / OneDrive / Files' },
  { id:'DocumentShared', name:'DocumentShared', description:'Document shared (SharePoint, OneDrive)', category:'SharePoint / OneDrive / Files' },
  { id:'FileAccessed', name:'FileAccessed', description:'File accessed (SharePoint, OneDrive)', category:'SharePoint / OneDrive / Files' },
  { id:'FileDeleted', name:'FileDeleted', description:'File deleted (SharePoint, OneDrive)', category:'SharePoint / OneDrive / Files' },
  { id:'FileModified', name:'FileModified', description:'File modified (SharePoint, OneDrive)', category:'SharePoint / OneDrive / Files' },
  { id:'MailboxLogin', name:'MailboxLogin', description:'User logged into mailbox (Exchange)', category:'Exchange / Outlook / Mailbox' },
  { id:'MailItemsAccessed', name:'MailItemsAccessed', description:'Mail item accessed (Exchange)', category:'Exchange / Outlook / Mailbox' },
  { id:'MailItemsDeleted', name:'MailItemsDeleted', description:'Mail item deleted (Exchange)', category:'Exchange / Outlook / Mailbox' },
  { id:'MailItemsSent', name:'MailItemsSent', description:'Mail item sent (Exchange)', category:'Exchange / Outlook / Mailbox' },
  { id:'MeetingCreated', name:'MeetingCreated', description:'User created a Teams meeting', category:'Teams / Meetings / Chat / Channels' },
  { id:'MeetingJoined', name:'MeetingJoined', description:'User joined a Teams meeting', category:'Teams / Meetings / Chat / Channels' },
  { id:'MessageRead', name:'MessageRead', description:'Message read (Teams, Exchange)', category:'Other / General' },
  { id:'MessageSent', name:'MessageSent', description:'Message sent (Teams, Exchange)', category:'Other / General' },
  { id:'SiteAccessed', name:'SiteAccessed', description:'SharePoint site accessed', category:'SharePoint / OneDrive / Files' },
  { id:'TeamCreated', name:'TeamCreated', description:'New Team created', category:'Teams / Meetings / Chat / Channels' },
  { id:'UserLoggedIn', name:'UserLoggedIn', description:'User signed in (all products)', category:'Azure AD / Identity / Sign-ins' }
];

export const ALL_ACTIVITIES: Record<string, Activity[]> = {
  'Copilot & AI': RELEVANT_ACTIVITIES.filter(a=>a.category==='Copilot & AI'),
  'Exchange / Outlook / Mailbox': RELEVANT_ACTIVITIES.filter(a=>a.category==='Exchange / Outlook / Mailbox'),
  'Teams / Meetings / Chat / Channels': RELEVANT_ACTIVITIES.filter(a=>a.category==='Teams / Meetings / Chat / Channels'),
  'SharePoint / OneDrive / Files': RELEVANT_ACTIVITIES.filter(a=>a.category==='SharePoint / OneDrive / Files'),
  'Azure AD / Identity / Sign-ins': RELEVANT_ACTIVITIES.filter(a=>a.category==='Azure AD / Identity / Sign-ins'),
  'Security & Compliance': [],
  'Other / General': RELEVANT_ACTIVITIES.filter(a=>a.category==='Other / General')
};
