/**
 * DuplicateDetector
 * 
 * Scans Accounts for duplicates based on Name AND (Phone OR Website)
 * Returns a list of DataQualityIssue__c records for bulk processing
 * Bulkified to handle up to 10,000+ records efficiently
 */
public class DuplicateDetector {
    
    /**
     * Scans Accounts for duplicates based on Name AND (Phone OR Website)
     * @return List<DataQualityIssue__c> - List of duplicate issue records
     */
    public static List<DataQualityIssue__c> detectAccountDuplicates() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Accounts with necessary fields
        // Using SOQL to get all records in bulk
        List<Account> accounts = [
            SELECT Id, Name, Phone, Website, OwnerId, Owner.Name
            FROM Account
            WHERE Name != null
            ORDER BY Name
            LIMIT 10000
        ];
        
        if (accounts.isEmpty()) {
            return issues;
        }
        
        // Group accounts by normalized name (case-insensitive, trimmed)
        Map<String, List<Account>> accountsByName = new Map<String, List<Account>>();
        
        for (Account acc : accounts) {
            String normalizedName = normalizeString(acc.Name);
            if (!accountsByName.containsKey(normalizedName)) {
                accountsByName.put(normalizedName, new List<Account>());
            }
            accountsByName.get(normalizedName).add(acc);
        }
        
        // Track processed record pairs to avoid duplicate issues
        Set<String> processedPairs = new Set<String>();
        
        // Process each name group
        for (String nameKey : accountsByName.keySet()) {
            List<Account> nameGroup = accountsByName.get(nameKey);
            
            // Only process groups with 2+ accounts (potential duplicates)
            if (nameGroup.size() < 2) {
                continue;
            }
            
            // Find duplicates within this name group based on Phone OR Website
            for (Integer i = 0; i < nameGroup.size(); i++) {
                Account acc1 = nameGroup[i];
                String phone1 = normalizeString(acc1.Phone);
                String website1 = normalizeString(acc1.Website);
                
                for (Integer j = i + 1; j < nameGroup.size(); j++) {
                    Account acc2 = nameGroup[j];
                    String phone2 = normalizeString(acc2.Phone);
                    String website2 = normalizeString(acc2.Website);
                    
                    // Check if this pair has already been processed
                    String pairKey1 = acc1.Id + '_' + acc2.Id;
                    String pairKey2 = acc2.Id + '_' + acc1.Id;
                    
                    if (processedPairs.contains(pairKey1) || processedPairs.contains(pairKey2)) {
                        continue;
                    }
                    
                    // Determine if duplicates based on Phone OR Website match
                    Boolean isDuplicate = false;
                    String duplicateReason = '';
                    
                    if (phone1 != null && phone1 != '' && phone1 == phone2) {
                        isDuplicate = true;
                        duplicateReason = 'Duplicate Phone: ' + acc1.Phone;
                    } else if (website1 != null && website1 != '' && website1 == website2) {
                        isDuplicate = true;
                        duplicateReason = 'Duplicate Website: ' + acc1.Website;
                    }
                    
                    if (isDuplicate) {
                        // Mark pair as processed
                        processedPairs.add(pairKey1);
                        processedPairs.add(pairKey2);
                        
                        // Create issue records for both accounts
                        DateTime detectedDate = DateTime.now();
                        
                        // Issue for Account 1
                        issues.add(createIssueRecord(
                            acc1.Id,
                            'Account',
                            acc1.Name,
                            acc2.Id,
                            duplicateReason,
                            acc1.Owner != null ? acc1.Owner.Name : 'Unknown',
                            detectedDate
                        ));
                        
                        // Issue for Account 2
                        issues.add(createIssueRecord(
                            acc2.Id,
                            'Account',
                            acc2.Name,
                            acc1.Id,
                            duplicateReason,
                            acc2.Owner != null ? acc2.Owner.Name : 'Unknown',
                            detectedDate
                        ));
                    }
                }
            }
        }
        
        return issues;
    }
    
    /**
     * Helper method to normalize strings for comparison
     * Trims whitespace and converts to lowercase
     */
    private static String normalizeString(String input) {
        if (input == null) {
            return '';
        }
        return input.trim().toLowerCase();
    }
    
    /**
     * Helper method to create a DataQualityIssue__c record
     */
    private static DataQualityIssue__c createIssueRecord(
        String recordId,
        String objectType,
        String accountName,
        String duplicateRecordId,
        String reason,
        String ownerName,
        DateTime detectedDate
    ) {
        String description = 'Account "' + accountName + '" is a duplicate. ' + 
                            'Duplicate Record ID: ' + duplicateRecordId + '. ' + 
                            'Reason: ' + reason;
        
        return new DataQualityIssue__c(
            RecordId__c = recordId,
            ObjectType__c = objectType,
            IssueType__c = 'Duplicate',
            IssueSeverity__c = 'High',
            IssueDescription__c = description,
            RecordOwner__c = ownerName,
            Status__c = 'New',
            DetectedDate__c = detectedDate
        );
    }
}
