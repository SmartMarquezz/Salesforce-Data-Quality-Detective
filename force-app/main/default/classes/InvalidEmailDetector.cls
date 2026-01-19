/**
 * InvalidEmailDetector
 * 
 * Scans Contact and Lead email fields for invalid email addresses and common domain typos
 * Returns a list of DataQualityIssue__c records for bulk processing
 * Bulkified to handle up to 10,000+ records efficiently
 */
public class InvalidEmailDetector {
    
    /**
     * Map of common domain typos and their correct versions
     */
    private static final Map<String, String> DOMAIN_TYPOS = new Map<String, String>{
        'gmial.com' => 'gmail.com',
        'yahooo.com' => 'yahoo.com',
        'outlok.com' => 'outlook.com',
        'hotmial.com' => 'hotmail.com',
        'gmai.com' => 'gmail.com',
        'gmail.co' => 'gmail.com',
        'yahoo.co' => 'yahoo.com',
        'hotmail.co' => 'hotmail.com',
        'outlook.co' => 'outlook.com',
        'gmaill.com' => 'gmail.com',
        'yaho.com' => 'yahoo.com',
        'hotmai.com' => 'hotmail.com'
    };
    
    /**
     * Valid email regex pattern
     * Matches standard email format: local@domain.tld
     */
    private static final String EMAIL_REGEX_PATTERN = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
    
    /**
     * Scans Contact records for invalid email addresses and common domain typos
     * @return List<DataQualityIssue__c> - List of email issue records for Contacts
     */
    public static List<DataQualityIssue__c> detectContactEmailIssues() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Contacts with email addresses
        List<Contact> contacts = [
            SELECT Id, Email, OwnerId, Owner.Name
            FROM Contact
            WHERE Email != null
            LIMIT 10000
        ];
        
        if (contacts.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each contact
        for (Contact con : contacts) {
            String emailIssue = validateEmail(con.Email);
            
            if (emailIssue != null) {
                issues.add(createIssueRecord(
                    con.Id,
                    'Contact',
                    emailIssue,
                    con.Owner != null ? con.Owner.Name : 'Unknown',
                    detectedDate
                ));
            }
        }
        
        return issues;
    }
    
    /**
     * Scans Lead records for invalid email addresses and common domain typos
     * @return List<DataQualityIssue__c> - List of email issue records for Leads
     */
    public static List<DataQualityIssue__c> detectLeadEmailIssues() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Leads with email addresses
        List<Lead> leads = [
            SELECT Id, Email, OwnerId, Owner.Name
            FROM Lead
            WHERE Email != null
            LIMIT 10000
        ];
        
        if (leads.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each lead
        for (Lead lead : leads) {
            String emailIssue = validateEmail(lead.Email);
            
            if (emailIssue != null) {
                issues.add(createIssueRecord(
                    lead.Id,
                    'Lead',
                    emailIssue,
                    lead.Owner != null ? lead.Owner.Name : 'Unknown',
                    detectedDate
                ));
            }
        }
        
        return issues;
    }
    
    /**
     * Validates an email address and returns an issue description if invalid
     * @param email The email address to validate
     * @return String - Issue description if invalid, null if valid
     */
    private static String validateEmail(String email) {
        if (email == null || email.trim() == '') {
            return null;
        }
        
        String normalizedEmail = email.trim().toLowerCase();
        
        // Check if email matches valid regex pattern
        Pattern emailPattern = Pattern.compile(EMAIL_REGEX_PATTERN);
        Matcher emailMatcher = emailPattern.matcher(normalizedEmail);
        
        if (!emailMatcher.matches()) {
            return 'HIGH: Email does not match valid email format pattern. Email: ' + email;
        }
        
        // Extract domain from email
        String[] emailParts = normalizedEmail.split('@');
        if (emailParts.size() != 2) {
            return 'HIGH: Email format is invalid. Email: ' + email;
        }
        
        String domain = emailParts[1];
        
        // Check for common domain typos
        if (DOMAIN_TYPOS.containsKey(domain)) {
            String correctDomain = DOMAIN_TYPOS.get(domain);
            return 'MEDIUM: Email contains common domain typo "' + domain + 
                   '". Did you mean "' + correctDomain + '"? Email: ' + email;
        }
        
        // Email is valid
        return null;
    }
    
    /**
     * Helper method to create a DataQualityIssue__c record
     */
    private static DataQualityIssue__c createIssueRecord(
        String recordId,
        String objectType,
        String issueDescription,
        String ownerName,
        DateTime detectedDate
    ) {
        // Determine severity based on issue description
        String severity = issueDescription.startsWith('HIGH:') ? 'High' : 'Medium';
        
        // Clean up the description (remove HIGH:/MEDIUM: prefix for cleaner display)
        String cleanDescription = issueDescription.replace('HIGH: ', '').replace('MEDIUM: ', '');
        
        return new DataQualityIssue__c(
            RecordId__c = recordId,
            ObjectType__c = objectType,
            IssueType__c = 'Invalid Email',
            IssueSeverity__c = severity,
            IssueDescription__c = cleanDescription,
            RecordOwner__c = ownerName,
            Status__c = 'New',
            DetectedDate__c = detectedDate
        );
    }
}
