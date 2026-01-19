import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import runAllScans from '@salesforce/apex/DataQualityController.runAllScans';
import getIssuesSummary from '@salesforce/apex/DataQualityController.getIssuesSummary';
import getAllIssues from '@salesforce/apex/DataQualityController.getAllIssues';
import getIssuesByType from '@salesforce/apex/DataQualityController.getIssuesByType';
import markAsFixed from '@salesforce/apex/DataQualityController.markAsFixed';
import markAsIgnored from '@salesforce/apex/DataQualityController.markAsIgnored';
import bulkMarkAsFixed from '@salesforce/apex/DataQualityController.bulkMarkAsFixed';

export default class DataQualityDashboard extends LightningElement {
    @track issues = [];
    @track filteredIssues = [];
    @track summary = {
        totalCount: 0,
        highCount: 0,
        mediumCount: 0,
        lowCount: 0
    };
    @track isLoading = false;
    @track selectedFilter = 'All';
    @track errorMessage = '';

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.loadSummary();
        this.loadIssues();
    }

    async handleRunScan() {
        this.isLoading = true;
        this.errorMessage = '';
        
        try {
            const result = await runAllScans();
            this.showToast('Success', result, 'success');
            
            // Refresh data after scan
            await this.loadData();
        } catch (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadSummary() {
        try {
            const summaryData = await getIssuesSummary();
            
            this.summary = {
                totalCount: summaryData.totalCount || 0,
                highCount: summaryData.severityCounts?.High || 0,
                mediumCount: summaryData.severityCounts?.Medium || 0,
                lowCount: summaryData.severityCounts?.Low || 0
            };
        } catch (error) {
            console.error('Error loading summary:', error);
            this.errorMessage = error.body ? error.body.message : error.message;
        }
    }

    async loadIssues() {
        try {
            let issuesData;
            if (this.selectedFilter === 'All') {
                issuesData = await getAllIssues();
            } else {
                issuesData = await getIssuesByType({ issueType: this.selectedFilter });
            }
            
            // Add computed properties for template
            this.issues = issuesData.map(issue => ({
                ...issue,
                severityClass: this.getSeverityClass(issue.IssueSeverity__c),
                recordUrl: this.getRecordUrl(issue.RecordId__c)
            }));
            
            this.filteredIssues = [...this.issues];
        } catch (error) {
            console.error('Error loading issues:', error);
            this.errorMessage = error.body ? error.body.message : error.message;
            this.issues = [];
            this.filteredIssues = [];
        }
    }

    handleFilterChange(event) {
        const filter = event.currentTarget.dataset.filter;
        this.selectedFilter = filter;
        this.loadIssues();
    }

    async handleMarkAsFixed(event) {
        const issueId = event.currentTarget.dataset.id;
        this.isLoading = true;
        
        try {
            const result = await markAsFixed({ issueId: issueId });
            this.showToast('Success', result, 'success');
            
            // Refresh data
            await this.loadData();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleMarkAsIgnored(event) {
        const issueId = event.currentTarget.dataset.id;
        this.isLoading = true;
        
        try {
            const result = await markAsIgnored({ issueId: issueId });
            this.showToast('Success', result, 'success');
            
            // Refresh data
            await this.loadData();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getSeverityClass(severity) {
        if (!severity) return 'severity-badge';
        
        const severityLower = severity.toLowerCase();
        if (severityLower === 'high') {
            return 'severity-badge severity-high';
        } else if (severityLower === 'medium') {
            return 'severity-badge severity-medium';
        } else if (severityLower === 'low') {
            return 'severity-badge severity-low';
        }
        return 'severity-badge';
    }

    getRecordUrl(recordId) {
        if (!recordId) return '#';
        return `/${recordId}`;
    }

    get hasIssues() {
        return this.filteredIssues && this.filteredIssues.length > 0;
    }

    get allFilterVariant() {
        return this.selectedFilter === 'All' ? 'brand' : 'neutral';
    }

    get duplicateFilterVariant() {
        return this.selectedFilter === 'Duplicate' ? 'brand' : 'neutral';
    }

    get emailFilterVariant() {
        return this.selectedFilter === 'Invalid Email' ? 'brand' : 'neutral';
    }

    get phoneFilterVariant() {
        return this.selectedFilter === 'Invalid Phone' ? 'brand' : 'neutral';
    }

    get orphanedFilterVariant() {
        return this.selectedFilter === 'Orphaned Record' ? 'brand' : 'neutral';
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}
