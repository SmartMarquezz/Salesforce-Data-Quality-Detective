/**
 * OrphanedRecordDetector
 * 
 * Finds orphaned records (records missing required parent relationships)
 * Returns a list of DataQualityIssue__c records for bulk processing
 * Bulkified to handle up to 10,000+ records efficiently
 */
public class OrphanedRecordDetector {
    
    /**
     * Finds Contacts without AccountId (orphaned Contacts)
     * @return List<DataQualityIssue__c> - List of orphaned Contact issue records
     */
    public static List<DataQualityIssue__c> detectOrphanedContacts() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Contacts without AccountId
        List<Contact> contacts = [
            SELECT Id, Name, AccountId, OwnerId, Owner.Name,
                   (SELECT Id FROM Cases LIMIT 1),
                   (SELECT Id FROM Opportunities LIMIT 1)
            FROM Contact
            WHERE AccountId = null
            LIMIT 10000
        ];
        
        if (contacts.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each orphaned contact
        for (Contact con : contacts) {
            String description = 'Contact "' + (con.Name != null ? con.Name : 'Unnamed') + 
                               '" is missing Account relationship. ';
            
            // Add related records information
            Integer caseCount = con.Cases != null ? con.Cases.size() : 0;
            Integer oppCount = con.Opportunities != null ? con.Opportunities.size() : 0;
            
            if (caseCount > 0 || oppCount > 0) {
                description += 'This Contact has ';
                List<String> relatedInfo = new List<String>();
                if (caseCount > 0) {
                    relatedInfo.add(caseCount + ' Case' + (caseCount > 1 ? 's' : ''));
                }
                if (oppCount > 0) {
                    relatedInfo.add(oppCount + ' Opportunity' + (oppCount > 1 ? 'ies' : 'y'));
                }
                description += String.join(relatedInfo, ' and ') + '. ';
            }
            
            description += 'Suggestion: Link this Contact to an Account to maintain data integrity.';
            
            issues.add(createIssueRecord(
                con.Id,
                'Contact',
                description,
                con.Owner != null ? con.Owner.Name : 'Unknown',
                detectedDate
            ));
        }
        
        return issues;
    }
    
    /**
     * Finds Opportunities without AccountId (orphaned Opportunities)
     * @return List<DataQualityIssue__c> - List of orphaned Opportunity issue records
     */
    public static List<DataQualityIssue__c> detectOrphanedOpportunities() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Opportunities without AccountId
        List<Opportunity> opportunities = [
            SELECT Id, Name, AccountId, OwnerId, Owner.Name,
                   (SELECT Id FROM OpportunityContactRoles LIMIT 1)
            FROM Opportunity
            WHERE AccountId = null
            LIMIT 10000
        ];
        
        if (opportunities.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each orphaned opportunity
        for (Opportunity opp : opportunities) {
            String description = 'Opportunity "' + (opp.Name != null ? opp.Name : 'Unnamed') + 
                               '" is missing Account relationship. ';
            
            // Add related records information
            Integer ocrCount = opp.OpportunityContactRoles != null ? opp.OpportunityContactRoles.size() : 0;
            
            if (ocrCount > 0) {
                description += 'This Opportunity has ' + ocrCount + 
                             ' Contact Role' + (ocrCount > 1 ? 's' : '') + '. ';
            }
            
            description += 'Suggestion: Link this Opportunity to an Account to maintain data integrity.';
            
            issues.add(createIssueRecord(
                opp.Id,
                'Opportunity',
                description,
                opp.Owner != null ? opp.Owner.Name : 'Unknown',
                detectedDate
            ));
        }
        
        return issues;
    }
    
    /**
     * Finds Cases without AccountId AND ContactId (orphaned Cases)
     * @return List<DataQualityIssue__c> - List of orphaned Case issue records
     */
    public static List<DataQualityIssue__c> detectOrphanedCases() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all Cases without AccountId AND ContactId
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, AccountId, ContactId, OwnerId, Owner.Name
            FROM Case
            WHERE AccountId = null AND ContactId = null
            LIMIT 10000
        ];
        
        if (cases.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each orphaned case
        for (Case c : cases) {
            String caseIdentifier = c.CaseNumber != null ? 'Case #' + c.CaseNumber : 
                                   (c.Subject != null ? 'Case "' + c.Subject + '"' : 'Unnamed Case');
            
            String description = caseIdentifier + ' has no Account or Contact relationship. ';
            description += 'Suggestion: Link this Case to either an Account or Contact (or both) to maintain data integrity.';
            
            issues.add(createIssueRecord(
                c.Id,
                'Case',
                description,
                c.Owner != null ? c.Owner.Name : 'Unknown',
                detectedDate
            ));
        }
        
        return issues;
    }
    
    /**
     * Finds OpportunityContactRoles without ContactId (orphaned OpportunityContactRoles)
     * @return List<DataQualityIssue__c> - List of orphaned OpportunityContactRole issue records
     */
    public static List<DataQualityIssue__c> detectOrphanedOpportunityContactRoles() {
        List<DataQualityIssue__c> issues = new List<DataQualityIssue__c>();
        
        // Query all OpportunityContactRoles without ContactId
        List<OpportunityContactRole> ocrs = [
            SELECT Id, OpportunityId, Opportunity.Name, Opportunity.Owner.Name, ContactId, Role
            FROM OpportunityContactRole
            WHERE ContactId = null
            LIMIT 10000
        ];
        
        if (ocrs.isEmpty()) {
            return issues;
        }
        
        DateTime detectedDate = DateTime.now();
        
        // Process each orphaned opportunity contact role
        for (OpportunityContactRole ocr : ocrs) {
            String oppName = ocr.Opportunity != null && ocr.Opportunity.Name != null ? 
                            ocr.Opportunity.Name : 'Unnamed Opportunity';
            String roleInfo = ocr.Role != null ? ' (Role: ' + ocr.Role + ')' : '';
            
            String description = 'OpportunityContactRole for Opportunity "' + oppName + '"' + roleInfo + 
                               ' is missing Contact relationship. ';
            description += 'Suggestion: Link this OpportunityContactRole to a Contact to maintain data integrity.';
            
            String ownerName = 'Unknown';
            if (ocr.Opportunity != null && ocr.Opportunity.Owner != null && ocr.Opportunity.Owner.Name != null) {
                ownerName = ocr.Opportunity.Owner.Name;
            }
            
            issues.add(createIssueRecord(
                ocr.Id,
                'OpportunityContactRole',
                description,
                ownerName,
                detectedDate
            ));
        }
        
        return issues;
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
        return new DataQualityIssue__c(
            RecordId__c = recordId,
            ObjectType__c = objectType,
            IssueType__c = 'Orphaned Record',
            IssueSeverity__c = 'High',
            IssueDescription__c = issueDescription,
            RecordOwner__c = ownerName,
            Status__c = 'New',
            DetectedDate__c = detectedDate
        );
    }
}
