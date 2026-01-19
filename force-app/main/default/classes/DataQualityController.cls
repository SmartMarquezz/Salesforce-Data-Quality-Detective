/**
 * DataQualityController
 * 
 * Apex controller for Data Quality Detective Lightning components
 * Provides methods to scan for data quality issues and manage issue records
 */
public with sharing class DataQualityController {
    
    /**
     * Runs all data quality scans and saves results
     * Deletes existing 'New' issues before inserting new ones
     * @return String - Success message with total count
     */
    @AuraEnabled(cacheable=false)
    public static String runAllScans() {
        try {
            // Delete all existing 'New' issues to avoid duplicates
            List<DataQualityIssue__c> existingIssues = [
                SELECT Id FROM DataQualityIssue__c WHERE Status__c = 'New'
            ];
            
            if (!existingIssues.isEmpty()) {
                delete existingIssues;
            }
            
            // Run all detector scans
            List<DataQualityIssue__c> allIssues = new List<DataQualityIssue__c>();
            
            // Duplicate detection
            List<DataQualityIssue__c> duplicateIssues = DuplicateDetector.detectAccountDuplicates();
            if (duplicateIssues != null && !duplicateIssues.isEmpty()) {
                allIssues.addAll(duplicateIssues);
            }
            
            // Invalid email detection
            List<DataQualityIssue__c> emailIssues = InvalidEmailDetector.detectContactEmailIssues();
            if (emailIssues != null && !emailIssues.isEmpty()) {
                allIssues.addAll(emailIssues);
            }
            
            List<DataQualityIssue__c> leadEmailIssues = InvalidEmailDetector.detectLeadEmailIssues();
            if (leadEmailIssues != null && !leadEmailIssues.isEmpty()) {
                allIssues.addAll(leadEmailIssues);
            }
            
            // Invalid phone detection
            List<DataQualityIssue__c> accountPhoneIssues = InvalidPhoneDetector.detectAccountPhoneIssues();
            if (accountPhoneIssues != null && !accountPhoneIssues.isEmpty()) {
                allIssues.addAll(accountPhoneIssues);
            }
            
            List<DataQualityIssue__c> contactPhoneIssues = InvalidPhoneDetector.detectContactPhoneIssues();
            if (contactPhoneIssues != null && !contactPhoneIssues.isEmpty()) {
                allIssues.addAll(contactPhoneIssues);
            }
            
            List<DataQualityIssue__c> leadPhoneIssues = InvalidPhoneDetector.detectLeadPhoneIssues();
            if (leadPhoneIssues != null && !leadPhoneIssues.isEmpty()) {
                allIssues.addAll(leadPhoneIssues);
            }
            
            // Orphaned record detection
            List<DataQualityIssue__c> orphanedContacts = OrphanedRecordDetector.detectOrphanedContacts();
            if (orphanedContacts != null && !orphanedContacts.isEmpty()) {
                allIssues.addAll(orphanedContacts);
            }
            
            List<DataQualityIssue__c> orphanedOpportunities = OrphanedRecordDetector.detectOrphanedOpportunities();
            if (orphanedOpportunities != null && !orphanedOpportunities.isEmpty()) {
                allIssues.addAll(orphanedOpportunities);
            }
            
            List<DataQualityIssue__c> orphanedCases = OrphanedRecordDetector.detectOrphanedCases();
            if (orphanedCases != null && !orphanedCases.isEmpty()) {
                allIssues.addAll(orphanedCases);
            }
            
            List<DataQualityIssue__c> orphanedOCRs = OrphanedRecordDetector.detectOrphanedOpportunityContactRoles();
            if (orphanedOCRs != null && !orphanedOCRs.isEmpty()) {
                allIssues.addAll(orphanedOCRs);
            }
            
            // Insert all issues in bulk
            if (!allIssues.isEmpty()) {
                insert allIssues;
                return 'Scan completed successfully! Found ' + allIssues.size() + ' data quality issue(s).';
            } else {
                return 'Scan completed successfully! No data quality issues found.';
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error running data quality scan: ' + e.getMessage());
        }
    }
    
    /**
     * Returns summary statistics of data quality issues
     * @return Map<String, Object> - Summary data with counts by type and severity
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getIssuesSummary() {
        Map<String, Object> summary = new Map<String, Object>();
        
        try {
            // Aggregate queries for efficient counting
            List<AggregateResult> typeCounts = [
                SELECT IssueType__c, COUNT(Id) cnt
                FROM DataQualityIssue__c
                WHERE Status__c IN ('New', 'Reviewed')
                GROUP BY IssueType__c
            ];
            
            List<AggregateResult> severityCounts = [
                SELECT IssueSeverity__c, COUNT(Id) cnt
                FROM DataQualityIssue__c
                WHERE Status__c IN ('New', 'Reviewed')
                GROUP BY IssueSeverity__c
            ];
            
            // Build type counts map
            Map<String, Integer> typeMap = new Map<String, Integer>();
            Integer totalCount = 0;
            
            for (AggregateResult ar : typeCounts) {
                String issueType = (String)ar.get('IssueType__c');
                Integer count = (Integer)ar.get('cnt');
                typeMap.put(issueType, count);
                totalCount += count;
            }
            
            // Build severity counts map
            Map<String, Integer> severityMap = new Map<String, Integer>();
            
            for (AggregateResult ar : severityCounts) {
                String severity = (String)ar.get('IssueSeverity__c');
                Integer count = (Integer)ar.get('cnt');
                severityMap.put(severity, count);
            }
            
            summary.put('totalCount', totalCount);
            summary.put('typeCounts', typeMap);
            summary.put('severityCounts', severityMap);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving summary: ' + e.getMessage());
        }
        
        return summary;
    }
    
    /**
     * Returns all data quality issues (New or Reviewed status)
     * @return List<DataQualityIssue__c> - List of issues ordered by severity and date
     */
    @AuraEnabled(cacheable=true)
    public static List<DataQualityIssue__c> getAllIssues() {
        try {
            List<DataQualityIssue__c> issues = [
                SELECT Id, RecordId__c, ObjectType__c, IssueType__c, IssueSeverity__c,
                       IssueDescription__c, RecordOwner__c, Status__c, DetectedDate__c, FixedDate__c
                FROM DataQualityIssue__c
                WHERE Status__c IN ('New', 'Reviewed')
                ORDER BY DetectedDate__c DESC
                LIMIT 2000
            ];
            
            // Sort by severity (High, Medium, Low) then by date
            Map<String, Integer> severityOrder = new Map<String, Integer>{
                'High' => 1,
                'Medium' => 2,
                'Low' => 3
            };
            
            List<DataQualityIssue__c> sortedIssues = new List<DataQualityIssue__c>();
            sortedIssues.addAll(issues);
            
            sortedIssues.sort(new IssueSeverityComparator(severityOrder));
            
            return sortedIssues;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving issues: ' + e.getMessage());
        }
    }
    
    /**
     * Returns filtered data quality issues by type
     * @param issueType - The issue type to filter by ('Duplicate', 'Invalid Email', 'Invalid Phone', 'Orphaned Record')
     * @return List<DataQualityIssue__c> - Filtered list of issues
     */
    @AuraEnabled(cacheable=true)
    public static List<DataQualityIssue__c> getIssuesByType(String issueType) {
        try {
            if (String.isBlank(issueType)) {
                return getAllIssues();
            }
            
            List<DataQualityIssue__c> issues = [
                SELECT Id, RecordId__c, ObjectType__c, IssueType__c, IssueSeverity__c,
                       IssueDescription__c, RecordOwner__c, Status__c, DetectedDate__c, FixedDate__c
                FROM DataQualityIssue__c
                WHERE Status__c IN ('New', 'Reviewed')
                  AND IssueType__c = :issueType
                ORDER BY DetectedDate__c DESC
                LIMIT 2000
            ];
            
            // Sort by severity (High, Medium, Low) then by date
            Map<String, Integer> severityOrder = new Map<String, Integer>{
                'High' => 1,
                'Medium' => 2,
                'Low' => 3
            };
            
            List<DataQualityIssue__c> sortedIssues = new List<DataQualityIssue__c>();
            sortedIssues.addAll(issues);
            
            sortedIssues.sort(new IssueSeverityComparator(severityOrder));
            
            return sortedIssues;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving issues by type: ' + e.getMessage());
        }
    }
    
    /**
     * Marks a single issue as Fixed
     * @param issueId - The DataQualityIssue__c record ID
     * @return String - Success message
     */
    @AuraEnabled(cacheable=false)
    public static String markAsFixed(String issueId) {
        try {
            if (String.isBlank(issueId)) {
                throw new AuraHandledException('Issue ID is required');
            }
            
            DataQualityIssue__c issue = [
                SELECT Id, Status__c FROM DataQualityIssue__c WHERE Id = :issueId LIMIT 1
            ];
            
            issue.Status__c = 'Fixed';
            issue.FixedDate__c = DateTime.now();
            
            update issue;
            
            return 'Issue marked as Fixed successfully.';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error marking issue as fixed: ' + e.getMessage());
        }
    }
    
    /**
     * Marks a single issue as Ignored
     * @param issueId - The DataQualityIssue__c record ID
     * @return String - Success message
     */
    @AuraEnabled(cacheable=false)
    public static String markAsIgnored(String issueId) {
        try {
            if (String.isBlank(issueId)) {
                throw new AuraHandledException('Issue ID is required');
            }
            
            DataQualityIssue__c issue = [
                SELECT Id, Status__c FROM DataQualityIssue__c WHERE Id = :issueId LIMIT 1
            ];
            
            issue.Status__c = 'Ignored';
            
            update issue;
            
            return 'Issue marked as Ignored successfully.';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error marking issue as ignored: ' + e.getMessage());
        }
    }
    
    /**
     * Bulk marks multiple issues as Fixed
     * @param issueIds - List of DataQualityIssue__c record IDs
     * @return String - Success message with count
     */
    @AuraEnabled(cacheable=false)
    public static String bulkMarkAsFixed(List<String> issueIds) {
        try {
            if (issueIds == null || issueIds.isEmpty()) {
                throw new AuraHandledException('At least one Issue ID is required');
            }
            
            List<DataQualityIssue__c> issues = [
                SELECT Id, Status__c FROM DataQualityIssue__c WHERE Id IN :issueIds
            ];
            
            if (issues.isEmpty()) {
                throw new AuraHandledException('No issues found with the provided IDs');
            }
            
            DateTime now = DateTime.now();
            for (DataQualityIssue__c issue : issues) {
                issue.Status__c = 'Fixed';
                issue.FixedDate__c = now;
            }
            
            update issues;
            
            return issues.size() + ' issue(s) marked as Fixed successfully.';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error bulk marking issues as fixed: ' + e.getMessage());
        }
    }
    
    /**
     * Comparator class for sorting issues by severity
     */
    private class IssueSeverityComparator implements Comparator<DataQualityIssue__c> {
        private Map<String, Integer> severityOrder;
        
        public IssueSeverityComparator(Map<String, Integer> severityOrder) {
            this.severityOrder = severityOrder;
        }
        
        public Integer compare(DataQualityIssue__c issue1, DataQualityIssue__c issue2) {
            Integer order1 = severityOrder.containsKey(issue1.IssueSeverity__c) ? 
                           severityOrder.get(issue1.IssueSeverity__c) : 999;
            Integer order2 = severityOrder.containsKey(issue2.IssueSeverity__c) ? 
                           severityOrder.get(issue2.IssueSeverity__c) : 999;
            
            // First compare by severity order
            if (order1 != order2) {
                return order1 - order2;
            }
            
            // Then compare by date (newest first)
            if (issue1.DetectedDate__c != null && issue2.DetectedDate__c != null) {
                if (issue1.DetectedDate__c > issue2.DetectedDate__c) {
                    return -1;
                } else if (issue1.DetectedDate__c < issue2.DetectedDate__c) {
                    return 1;
                }
            } else if (issue1.DetectedDate__c != null) {
                return -1;
            } else if (issue2.DetectedDate__c != null) {
                return 1;
            }
            
            return 0;
        }
    }
}
