/**
 * InvalidPhoneDetector
 * 
 * Scans Account, Contact, and Lead phone fields for invalid phone numbers
 * Detects issues like letters, incorrect length, and fake patterns
 * Returns a list of DataQualityIssue__c records for bulk processing
 * Bulkified to handle up to 10,000+ records efficiently
 */
public class InvalidPhoneDetector {
    
    /**
     * Scans Account.Phone field for invalid phone numbers
     * @return List<DataQualityIssue__c> - List of phone issue records for Accounts
     */
    public static List<DataQualityIssue__c> detectAccountPhoneIssues() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Accounts with phone numbers
        List<Account> accounts = [
            SELECT Id, Phone, OwnerId, Owner.Name
            FROM Account
            WHERE Phone != null
            LIMIT 10000
        ];
        
        if (accounts.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each account
        for (Account acc : accounts) {
            String phoneIssue = validatePhone(acc.Phone);
            
            if (phoneIssue != null) {
                issues.add(createIssueRecord(
                    acc.Id,
                    'Account',
                    phoneIssue,
                    acc.Owner != null ? acc.Owner.Name : 'Unknown',
                    detectedDate
                ));
            }
        }
        
        return issues;
    }
    
    /**
     * Scans Contact.Phone and Contact.MobilePhone fields for invalid phone numbers
     * @return List<DataQualityIssue__c> - List of phone issue records for Contacts
     */
    public static List<DataQualityIssue__c> detectContactPhoneIssues() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Contacts with phone numbers
        List<Contact> contacts = [
            SELECT Id, Phone, MobilePhone, OwnerId, Owner.Name
            FROM Contact
            WHERE Phone != null OR MobilePhone != null
            LIMIT 10000
        ];
        
        if (contacts.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each contact
        for (Contact con : contacts) {
            // Check Phone field
            if (con.Phone != null) {
                String phoneIssue = validatePhone(con.Phone);
                if (phoneIssue != null) {
                    issues.add(createIssueRecord(
                        con.Id,
                        'Contact',
                        'Phone: ' + phoneIssue,
                        con.Owner != null ? con.Owner.Name : 'Unknown',
                        detectedDate
                    ));
                }
            }
            
            // Check MobilePhone field
            if (con.MobilePhone != null) {
                String mobileIssue = validatePhone(con.MobilePhone);
                if (mobileIssue != null) {
                    issues.add(createIssueRecord(
                        con.Id,
                        'Contact',
                        'MobilePhone: ' + mobileIssue,
                        con.Owner != null ? con.Owner.Name : 'Unknown',
                        detectedDate
                    ));
                }
            }
        }
        
        return issues;
    }
    
    /**
     * Scans Lead.Phone field for invalid phone numbers
     * @return List<DataQualityIssue__c> - List of phone issue records for Leads
     */
    public static List<DataQualityIssue__c> detectLeadPhoneIssues() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Leads with phone numbers
        List<Lead> leads = [
            SELECT Id, Phone, OwnerId, Owner.Name
            FROM Lead
            WHERE Phone != null
            LIMIT 10000
        ];
        
        if (leads.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each lead
        for (Lead lead : leads) {
            String phoneIssue = validatePhone(lead.Phone);
            
            if (phoneIssue != null) {
                issues.add(createIssueRecord(
                    lead.Id,
                    'Lead',
                    phoneIssue,
                    lead.Owner != null ? lead.Owner.Name : 'Unknown',
                    detectedDate
                ));
            }
        }
        
        return issues;
    }
    
    /**
     * Validates a phone number and returns an issue description if invalid
     * @param phone The phone number to validate
     * @return String - Issue description if invalid, null if valid
     */
    private static String validatePhone(String phone) {
        if (phone == null || phone.trim() == '') {
            return null;
        }
        
        String trimmedPhone = phone.trim();
        
        // Check for letters (except 'x' for extensions)
        String phoneWithoutExtension = trimmedPhone.toLowerCase();
        // Remove 'x' and digits to check for other letters
        String lettersOnly = phoneWithoutExtension.replaceAll('[0-9x\\s\\-\\(\\)\\.\\+]', '');
        if (lettersOnly.length() > 0) {
            return 'HIGH: Phone contains invalid letters. Phone: ' + phone;
        }
        
        // Extract digits (allowing 'x' for extensions)
        String digits = extractDigits(trimmedPhone);
        
        // Check length
        if (digits.length() < 10) {
            return 'HIGH: Phone number too short (less than 10 digits). Phone: ' + phone;
        }
        
        if (digits.length() > 15) {
            return 'HIGH: Phone number too long (more than 15 digits). Phone: ' + phone;
        }
        
        // Check for fake patterns
        String fakePattern = isFakePattern(digits);
        if (fakePattern != null) {
            return 'MEDIUM: ' + fakePattern + '. Phone: ' + phone;
        }
        
        // Phone is valid
        return null;
    }
    
    /**
     * Extracts digits from phone number, preserving 'x' for extensions
     * @param phone The phone number string
     * @return String - Digits only (with 'x' if present)
     */
    private static String extractDigits(String phone) {
        if (phone == null) {
            return '';
        }
        
        // Remove all non-digit characters except 'x' (case insensitive)
        String result = phone.replaceAll('[^0-9xX]', '');
        return result.toLowerCase();
    }
    
    /**
     * Checks if phone number matches known fake patterns
     * @param digits The phone number digits (without formatting)
     * @return String - Description of fake pattern if found, null otherwise
     */
    private static String isFakePattern(String digits) {
        if (digits == null || digits.length() < 10) {
            return null;
        }
        
        // Remove 'x' and extension for pattern checking
        String digitsOnly = digits.replace('x', '');
        if (digitsOnly.length() < 10) {
            return null;
        }
        
        // Take first 10 digits for pattern checking
        String tenDigits = digitsOnly.substring(0, 10);
        
        // Check for all same digit (111-111-1111, 222-222-2222, etc.)
        Pattern sameDigitPattern = Pattern.compile('^(\\d)\\1{9}$');
        Matcher sameDigitMatcher = sameDigitPattern.matcher(tenDigits);
        if (sameDigitMatcher.matches()) {
            return 'Fake pattern: All same digit (' + tenDigits.substring(0, 3) + '-' + 
                   tenDigits.substring(3, 6) + '-' + tenDigits.substring(6) + ')';
        }
        
        // Check for 111-111-1111
        if (tenDigits == '1111111111') {
            return 'Fake pattern: 111-111-1111';
        }
        
        // Check for 000-000-0000
        if (tenDigits == '0000000000') {
            return 'Fake pattern: 000-000-0000';
        }
        
        // Check for 123-456-7890
        if (tenDigits == '1234567890') {
            return 'Fake pattern: 123-456-7890';
        }
        
        // Check for 555-555-5555
        if (tenDigits == '5555555555') {
            return 'Fake pattern: 555-555-5555';
        }
        
        // Check for sequential patterns (1234, 2345, etc.)
        Boolean isSequential = true;
        for (Integer i = 0; i < tenDigits.length() - 1; i++) {
            Integer current = Integer.valueOf(tenDigits.substring(i, i + 1));
            Integer next = Integer.valueOf(tenDigits.substring(i + 1, i + 2));
            if (next != current + 1) {
                isSequential = false;
                break;
            }
        }
        if (isSequential) {
            return 'Fake pattern: Sequential digits (' + tenDigits.substring(0, 3) + '-' + 
                   tenDigits.substring(3, 6) + '-' + tenDigits.substring(6) + ')';
        }
        
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
            IssueType__c = 'Invalid Phone',
            IssueSeverity__c = severity,
            IssueDescription__c = cleanDescription,
            RecordOwner__c = ownerName,
            Status__c = 'New',
            DetectedDate__c = detectedDate
        );
    }
}
