const { Document, Packer, Paragraph, TextRun, AlignmentType, HeadingLevel, ExternalHyperlink } = require('docx');
const fs = require('fs');

function line(label, value) {
  return new Paragraph({
    spacing: { line: 320, before: 60, after: 60 },
    children: [
      new TextRun({ text: label + ': ', font: 'Times New Roman', size: 24, bold: true }),
      new TextRun({ text: value, font: 'Times New Roman', size: 24 }),
    ],
  });
}

function link(label, url) {
  return new Paragraph({
    spacing: { line: 320, before: 60, after: 60 },
    children: [
      new TextRun({ text: label + ': ', font: 'Times New Roman', size: 24, bold: true }),
      new ExternalHyperlink({
        link: url,
        children: [new TextRun({ text: url, font: 'Times New Roman', size: 24, color: '1155CC', underline: {} })],
      }),
    ],
  });
}

function blank() {
  return new Paragraph({ spacing: { before: 0, after: 100 }, children: [new TextRun('')] });
}

function sectionTitle(text) {
  return new Paragraph({
    spacing: { before: 200, after: 100 },
    border: { bottom: { style: 'single', size: 6, color: '2E4A8B' } },
    children: [new TextRun({ text, font: 'Times New Roman', size: 24, bold: true, color: '1F3864' })],
  });
}

function bodyPara(text) {
  return new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: { line: 320, before: 60, after: 60 },
    children: [new TextRun({ text, font: 'Times New Roman', size: 22 })],
  });
}

const doc = new Document({
  styles: { default: { document: { run: { font: 'Times New Roman', size: 24 } } } },
  sections: [{
    properties: {
      page: {
        size: { width: 11906, height: 16838 },
        margin: { top: 1440, right: 1440, bottom: 1440, left: 1800 },
      },
    },
    children: [
      // Title
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 160 },
        children: [new TextRun({ text: 'PROFESSIONAL PROFILE', font: 'Times New Roman', size: 28, bold: true, color: '1F3864' })],
      }),

      // Personal
      sectionTitle('Student Details'),
      blank(),
      line('Name', 'Akash Kumar'),
      line('Registration No.', '12216095'),
      line('Programme', 'Bachelor of Technology – Computer Science and Engineering'),
      line('Institution', 'Lovely Professional University, Punjab'),
      blank(),

      // Online Profiles
      sectionTitle('Online Profiles'),
      blank(),
      link('GitHub', 'https://github.com/akashkumar-05'),
      link('LinkedIn', 'https://www.linkedin.com/in/akashsight30/'),
      blank(),

      // Project
      sectionTitle('Project Overview'),
      blank(),
      line('Problem Statement ID', '25035 – Ministry of Corporate Affairs'),
      line('Title', 'AI-Driven Sentiment Analysis of Stakeholder Feedback Submitted Through the MCA eConsultation Module'),
      blank(),
      bodyPara('This project develops an end-to-end AI-powered system to automate the analysis of public stakeholder feedback submitted on the MCA eConsultation portal. A fine-tuned RoBERTa model performs three-class sentiment classification (Positive / Neutral / Negative) with confidence scoring, while BART-large-CNN generates abstractive summaries and a word cloud module visualises key themes. The system is built on a microservices architecture — Spring Boot (Java) backend integrated with a Python Flask AI service — secured via Spring Security and Google OAuth2, with PostgreSQL persistence and interactive Chart.js dashboards. Downloadable PDF and CSV reports are generated using the iText 7 library.'),
      blank(),

      // Supervisor
      sectionTitle('Supervised By'),
      blank(),
      line('Name', 'Bharat Sharma'),
      line('Designation', 'Assistant Professor, School of Computer Science and Engineering'),
      blank(), blank(),

      // Signature
      new Paragraph({
        spacing: { line: 320, before: 60, after: 60 },
        children: [new TextRun({ text: 'Signature: ___________________          Date: ___________________', font: 'Times New Roman', size: 24 })],
      }),
    ],
  }],
});

Packer.toBuffer(doc).then(buf => {
  const out = 'd:\\Projects\\project_MCA\\mca-econsultation\\Appendix_Profile_v2.docx';
  fs.writeFileSync(out, buf);
  console.log('Done:', out);
}).catch(err => { console.error(err); process.exit(1); });
