public with sharing class DataQualityTestDataGenerator {
    
    private static final String TEST_PREFIX = 'TEST_DQD_';
    
    /**
     * Generates test data with various data quality issues
     * @return Summary string of what was created
     */
    public static String generateBadData() {
        List<String> summary = new List<String>();
        Integer successCount = 0;
        Integer errorCount = 0;
        
        // Delete existing test data first
        deleteTestData();
        
        // Get users for random owner assignment
        List<User> users = [SELECT Id FROM User WHERE IsActive = true LIMIT 10];
        if (users.isEmpty()) {
            User currentUser = new User(Id = UserInfo.getUserId());
            users = new List<User>{currentUser};
        }
        
        // 1. Create 20 Accounts with duplicate names (10 pairs)
        List<Account> duplicateAccounts = new List<Account>();
        String[] companyNames = new String[]{
            'Acme Corporation', 'Global Tech Solutions', 'Premier Services Inc',
            'Advanced Systems LLC', 'Innovative Solutions Group', 'Elite Business Partners',
            'Strategic Consulting Group', 'Prime Manufacturing Co', 'Dynamic Enterprises',
            'Summit Industries Ltd'
        };
        
        for (Integer i = 0; i < 10; i++) {
            String companyName = TEST_PREFIX + companyNames[i];
            User randomOwner = users[Math.mod(i, users.size())];
            
            // First account in pair
            Account acc1 = new Account(
                Name = companyName,
                Phone = i < 5 ? '555-010' + String.valueOf(i) : null,
                Website = i >= 5 ? 'www.' + companyName.toLowerCase().replace(' ', '') + '.com' : null,
                OwnerId = randomOwner.Id
            );
            duplicateAccounts.add(acc1);
            
            // Second account in pair (duplicate)
            Account acc2 = new Account(
                Name = companyName,
                Phone = i < 5 ? '555-010' + String.valueOf(i) : null,
                Website = i >= 5 ? 'www.' + companyName.toLowerCase().replace(' ', '') + '.com' : null,
                OwnerId = users[Math.mod(i + 1, users.size())].Id
            );
            duplicateAccounts.add(acc2);
        }
        
        Database.SaveResult[] accountResults = Database.insert(duplicateAccounts, false);
        Integer accountSuccess = 0;
        for (Database.SaveResult sr : accountResults) {
            if (sr.isSuccess()) accountSuccess++;
            else errorCount++;
        }
        successCount += accountSuccess;
        summary.add('Accounts: ' + accountSuccess + ' created (duplicates)');
        
        // Get created account IDs for linking
        List<Account> createdAccounts = [SELECT Id FROM Account WHERE Name LIKE :TEST_PREFIX + '%' LIMIT 20];
        Map<Integer, Id> accountMap = new Map<Integer, Id>();
        for (Integer i = 0; i < createdAccounts.size(); i++) {
            accountMap.put(i, createdAccounts[i].Id);
        }
        
        // 2. Create 25 Contacts with invalid emails
        List<Contact> invalidEmailContacts = new List<Contact>();
        
        // 10 with domain typos
        String[] domainTypos = new String[]{
            'gmial.com', 'yahooo.com', 'outlok.com', 'hotmial.com', 'gmai.com',
            'gmail.co', 'yahoo.co', 'hotmail.co', 'outlook.co', 'gmaill.com'
        };
        String[] firstNames = new String[]{
            'John', 'Jane', 'Bob', 'Alice', 'Charlie', 'Diana', 'Edward', 'Fiona',
            'George', 'Helen', 'Ivan', 'Julia', 'Kevin', 'Laura', 'Michael'
        };
        String[] lastNames = new String[]{
            'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller',
            'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Wilson', 'Anderson', 'Thomas'
        };
        
        for (Integer i = 0; i < 10; i++) {
            Contact con = new Contact(
                FirstName = TEST_PREFIX + firstNames[Math.mod(i, firstNames.size())],
                LastName = lastNames[Math.mod(i, lastNames.size())],
                Email = firstNames[Math.mod(i, firstNames.size())].toLowerCase() + '.' + 
                       lastNames[Math.mod(i, lastNames.size())].toLowerCase() + '@' + domainTypos[i],
                OwnerId = users[Math.mod(i, users.size())].Id
            );
            // Link some to accounts
            if (i < 7 && accountMap.containsKey(i)) {
                con.AccountId = accountMap.get(i);
            }
            invalidEmailContacts.add(con);
        }
        
        // 10 with invalid format
        for (Integer i = 0; i < 10; i++) {
            String invalidEmail;
            if (i < 3) {
                invalidEmail = 'missingat' + String.valueOf(i) + 'gmail.com'; // Missing @
            } else if (i < 6) {
                invalidEmail = 'spaces in@email' + String.valueOf(i) + '.com'; // Spaces
            } else {
                invalidEmail = 'special@@chars' + String.valueOf(i) + '.com'; // Double @
            }
            
            Contact con = new Contact(
                FirstName = TEST_PREFIX + firstNames[Math.mod(i + 10, firstNames.size())],
                LastName = lastNames[Math.mod(i + 10, lastNames.size())],
                Email = invalidEmail,
                OwnerId = users[Math.mod(i, users.size())].Id
            );
            // Link some to accounts
            if (i < 5 && accountMap.containsKey(i + 5)) {
                con.AccountId = accountMap.get(i + 5);
            }
            invalidEmailContacts.add(con);
        }
        
        // 5 with completely random invalid emails
        for (Integer i = 0; i < 5; i++) {
            Contact con = new Contact(
                FirstName = TEST_PREFIX + firstNames[Math.mod(i + 5, firstNames.size())],
                LastName = lastNames[Math.mod(i + 5, lastNames.size())],
                Email = 'random' + String.valueOf(i) + 'invalid' + String.valueOf(System.now().getTime()),
                OwnerId = users[Math.mod(i, users.size())].Id
            );
            invalidEmailContacts.add(con);
        }
        
        Database.SaveResult[] emailContactResults = Database.insert(invalidEmailContacts, false);
        Integer emailContactSuccess = 0;
        for (Database.SaveResult sr : emailContactResults) {
            if (sr.isSuccess()) emailContactSuccess++;
            else errorCount++;
        }
        successCount += emailContactSuccess;
        summary.add('Contacts with invalid emails: ' + emailContactSuccess + ' created');
        
        // 3. Create 20 Contacts with invalid phones
        List<Contact> invalidPhoneContacts = new List<Contact>();
        
        // 5 with letters
        String[] phoneWithLetters = new String[]{
            '1-800-CALLME', '1-888-BUYNOW', '555-TEST-123', '1-877-HELP-US', '555-HELP-ME'
        };
        for (Integer i = 0; i < 5; i++) {
            Contact con = new Contact(
                FirstName = TEST_PREFIX + firstNames[Math.mod(i, firstNames.size())],
                LastName = lastNames[Math.mod(i + 5, lastNames.size())],
                Phone = phoneWithLetters[i],
                OwnerId = users[Math.mod(i, users.size())].Id
            );
            if (accountMap.containsKey(i)) {
                con.AccountId = accountMap.get(i);
            }
            invalidPhoneContacts.add(con);
        }
        
        // 5 too short
        for (Integer i = 0; i < 5; i++) {
            Contact con = new Contact(
                FirstName = TEST_PREFIX + firstNames[Math.mod(i + 5, firstNames.size())],
                LastName = lastNames[Math.mod(i + 10, lastNames.size())],
                Phone = '123-456' + String.valueOf(i),
                OwnerId = users[Math.mod(i, users.size())].Id
            );
            if (accountMap.containsKey(i + 2)) {
                con.AccountId = accountMap.get(i + 2);
            }
            invalidPhoneContacts.add(con);
        }
        
        // 5 with fake patterns
        String[] fakePatterns = new String[]{
            '111-111-1111', '000-000-0000', '123-456-7890', '222-222-2222', '555-555-5555'
        };
        for (Integer i = 0; i < 5; i++) {
            Contact con = new Contact(
                FirstName = TEST_PREFIX + firstNames[Math.mod(i + 10, firstNames.size())],
                LastName = lastNames[Math.mod(i, lastNames.size())],
                Phone = fakePatterns[i],
                MobilePhone = fakePatterns[i], // Also set mobile phone
                OwnerId = users[Math.mod(i, users.size())].Id
            );
            if (accountMap.containsKey(i + 3)) {
                con.AccountId = accountMap.get(i + 3);
            }
            invalidPhoneContacts.add(con);
        }
        
        // 5 too long
        for (Integer i = 0; i < 5; i++) {
            Contact con = new Contact(
                FirstName = TEST_PREFIX + firstNames[Math.mod(i + 2, firstNames.size())],
                LastName = lastNames[Math.mod(i + 7, lastNames.size())],
                Phone = '123456789012345' + String.valueOf(i),
                OwnerId = users[Math.mod(i, users.size())].Id
            );
            if (accountMap.containsKey(i + 4)) {
                con.AccountId = accountMap.get(i + 4);
            }
            invalidPhoneContacts.add(con);
        }
        
        Database.SaveResult[] phoneContactResults = Database.insert(invalidPhoneContacts, false);
        Integer phoneContactSuccess = 0;
        for (Database.SaveResult sr : phoneContactResults) {
            if (sr.isSuccess()) phoneContactSuccess++;
            else errorCount++;
        }
        successCount += phoneContactSuccess;
        summary.add('Contacts with invalid phones: ' + phoneContactSuccess + ' created');
        
        // 4. Create 15 orphaned Contacts
        List<Contact> orphanedContacts = new List<Contact>();
        for (Integer i = 0; i < 15; i++) {
            Contact con = new Contact(
                FirstName = TEST_PREFIX + firstNames[Math.mod(i, firstNames.size())],
                LastName = lastNames[Math.mod(i, lastNames.size())],
                Email = firstNames[Math.mod(i, firstNames.size())].toLowerCase() + '.' + 
                       lastNames[Math.mod(i, lastNames.size())].toLowerCase() + '@example.com',
                Phone = '555-0' + String.valueOf(100 + i),
                OwnerId = users[Math.mod(i, users.size())].Id
                // AccountId is null (orphaned)
            );
            orphanedContacts.add(con);
        }
        
        Database.SaveResult[] orphanedContactResults = Database.insert(orphanedContacts, false);
        Integer orphanedContactSuccess = 0;
        for (Database.SaveResult sr : orphanedContactResults) {
            if (sr.isSuccess()) orphanedContactSuccess++;
            else errorCount++;
        }
        successCount += orphanedContactSuccess;
        summary.add('Orphaned Contacts: ' + orphanedContactSuccess + ' created');
        
        // 5. Create 10 orphaned Opportunities
        List<Opportunity> orphanedOpps = new List<Opportunity>();
        String[] stages = new String[]{'Prospecting', 'Qualification', 'Needs Analysis', 'Value Proposition', 'Id. Decision Makers'};
        for (Integer i = 0; i < 10; i++) {
            Opportunity opp = new Opportunity(
                Name = TEST_PREFIX + 'Opportunity ' + String.valueOf(i + 1),
                StageName = stages[Math.mod(i, stages.size())],
                Amount = 10000 + (i * 5000),
                CloseDate = Date.today().addDays(30 + i),
                OwnerId = users[Math.mod(i, users.size())].Id
                // AccountId is null (orphaned)
            );
            orphanedOpps.add(opp);
        }
        
        Database.SaveResult[] oppResults = Database.insert(orphanedOpps, false);
        Integer oppSuccess = 0;
        for (Database.SaveResult sr : oppResults) {
            if (sr.isSuccess()) oppSuccess++;
            else errorCount++;
        }
        successCount += oppSuccess;
        summary.add('Orphaned Opportunities: ' + oppSuccess + ' created');
        
        // 6. Create 8 orphaned Cases
        List<Case> orphanedCases = new List<Case>();
        String[] caseStatuses = new String[]{'New', 'Working', 'Escalated', 'Closed'};
        String[] casePriorities = new String[]{'Low', 'Medium', 'High'};
        String[] caseTypes = new String[]{'Problem', 'Question', 'Feature Request', 'Other'};
        
        for (Integer i = 0; i < 8; i++) {
            Case c = new Case(
                Subject = TEST_PREFIX + 'Case ' + String.valueOf(i + 1),
                Status = caseStatuses[Math.mod(i, caseStatuses.size())],
                Priority = casePriorities[Math.mod(i, casePriorities.size())],
                Type = caseTypes[Math.mod(i, caseTypes.size())],
                Description = 'Test case description ' + String.valueOf(i + 1),
                OwnerId = users[Math.mod(i, users.size())].Id
                // AccountId and ContactId are null (orphaned)
            );
            orphanedCases.add(c);
        }
        
        Database.SaveResult[] caseResults = Database.insert(orphanedCases, false);
        Integer caseSuccess = 0;
        for (Database.SaveResult sr : caseResults) {
            if (sr.isSuccess()) caseSuccess++;
            else errorCount++;
        }
        successCount += caseSuccess;
        summary.add('Orphaned Cases: ' + caseSuccess + ' created');
        
        // Build summary string
        String result = 'Test Data Generation Complete!\n';
        result += 'Total Records Created: ' + successCount + '\n';
        result += 'Errors: ' + errorCount + '\n\n';
        result += 'Details:\n';
        for (String s : summary) {
            result += '- ' + s + '\n';
        }
        
        return result;
    }
    
    /**
     * Deletes all test data created by this generator
     */
    @TestVisible
    public static void deleteTestData() {
        // Delete Cases
        List<Case> testCases = [SELECT Id FROM Case WHERE Subject LIKE :TEST_PREFIX + '%'];
        if (!testCases.isEmpty()) {
            delete testCases;
        }
        
        // Delete Opportunities
        List<Opportunity> testOpps = [SELECT Id FROM Opportunity WHERE Name LIKE :TEST_PREFIX + '%'];
        if (!testOpps.isEmpty()) {
            delete testOpps;
        }
        
        // Delete Contacts
        List<Contact> testContacts = [SELECT Id FROM Contact WHERE FirstName LIKE :TEST_PREFIX + '%' OR LastName LIKE :TEST_PREFIX + '%'];
        if (!testContacts.isEmpty()) {
            delete testContacts;
        }
        
        // Delete Accounts
        List<Account> testAccounts = [SELECT Id FROM Account WHERE Name LIKE :TEST_PREFIX + '%'];
        if (!testAccounts.isEmpty()) {
            delete testAccounts;
        }
    }
}
