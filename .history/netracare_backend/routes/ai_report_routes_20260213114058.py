"""
AI Report Generation Routes
Aggregates all test results and generates comprehensive eye health reports with AI analysis
"""
from flask import request, jsonify, send_file
from flask_restx import Namespace, Resource, fields
from datetime import datetime, timedelta
from sqlalchemy import desc
import json
from auth_utils import token_required
from db_model import db, User, VisualAcuityTest, ColourVisionTest, BlinkFatigueTest, PupilReflexTest

# Create namespace
ai_report_ns = Namespace('ai-report', description='AI-Powered Comprehensive Eye Health Reports')

# API Models
generate_report_model = ai_report_ns.model('GenerateReport', {
    'report_type': fields.String(required=True, description='Type of report: comprehensive, visual_health, fatigue_analysis'),
    'include_tests': fields.List(fields.String, description='Test types to include: visual_acuity, colour_vision, blink_fatigue, pupil_reflex'),
    'time_range_days': fields.Integer(description='Number of days to include in report (default: 30)')
})

report_model = ai_report_ns.model('AIReport', {
    'report_id': fields.String(description='Report ID'),
    'user_id': fields.Integer(description='User ID'),
    'generation_date': fields.DateTime(description='Report generation date'),
    'report_type': fields.String(description='Report type'),
    'overall_score': fields.Float(description='Overall eye health score (0-100)'),
    'summary': fields.String(description='AI-generated summary'),
    'findings': fields.Raw(description='Detailed findings from all tests'),
    'recommendations': fields.List(fields.String, description='Personalized recommendations'),
    'trends': fields.Raw(description='Trend analysis over time')
})

def calculate_visual_acuity_score(tests):
    """Calculate score from visual acuity tests (0-100)"""
    if not tests:
        return None, "No visual acuity tests available"
    
    latest_test = tests[0]
    
    # Convert Snellen to score (20/20 = 100, 20/200 = 10)
    try:
        if latest_test.snellen_result:
            parts = latest_test.snellen_result.split('/')
            if len(parts) == 2:
                numerator = float(parts[0])
                denominator = float(parts[1])
                score = (numerator / denominator) * 100
                
                if score >= 95:
                    finding = "Excellent visual acuity"
                elif score >= 80:
                    finding = "Good visual acuity with minor impairment"
                elif score >= 60:
                    finding = "Moderate visual impairment"
                else:
                    finding = "Severe visual impairment requiring correction"
                
                return min(score, 100), finding
    except:
        pass
    
    return 70, "Visual acuity test completed, results inconclusive"

def calculate_colour_vision_score(tests):
    """Calculate score from colour vision tests (0-100)"""
    if not tests:
        return None, "No colour vision tests available"
    
    latest_test = tests[0]
    
    # Normal color vision = 100, deficiencies reduce score
    if not latest_test.deficiency_detected:
        return 100, "Normal colour vision detected"
    
    severity_scores = {
        'mild': 85,
        'moderate': 65,
        'severe': 40
    }
    
    score = severity_scores.get(latest_test.deficiency_severity, 70)
    finding = f"{latest_test.deficiency_type.replace('_', ' ').title()} colour vision deficiency ({latest_test.deficiency_severity})"
    
    return score, finding

def calculate_blink_fatigue_score(tests):
    """Calculate score from blink fatigue tests (0-100)"""
    if not tests:
        return None, "No blink fatigue tests available"
    
    latest_test = tests[0]
    
    # Optimal blink rate: 15-20 per minute
    blink_rate = latest_test.blink_rate if latest_test.blink_rate else 15
    
    if 15 <= blink_rate <= 20:
        blink_score = 100
        blink_finding = "Optimal blink rate"
    elif 10 <= blink_rate < 15 or 20 < blink_rate <= 25:
        blink_score = 80
        blink_finding = "Slightly abnormal blink rate"
    else:
        blink_score = 60
        blink_finding = "Abnormal blink rate indicating potential dry eye or fatigue"
    
    # Fatigue detection
    if latest_test.fatigue_detected:
        fatigue_penalty = 20 if latest_test.fatigue_level == 'high' else 10
        blink_score -= fatigue_penalty
        blink_finding += f"; {latest_test.fatigue_level.title()} fatigue detected"
    
    return max(blink_score, 0), blink_finding

def calculate_pupil_reflex_score(tests):
    """Calculate score from pupil reflex tests (0-100)"""
    if not tests:
        return None, "No pupil reflex tests available"
    
    latest_test = tests[0]
    score = 100
    findings = []
    
    # Check pupil response time (normal: <300ms)
    if latest_test.pupil_response_time_ms:
        if latest_test.pupil_response_time_ms > 400:
            score -= 20
            findings.append("Delayed pupil response")
        elif latest_test.pupil_response_time_ms > 300:
            score -= 10
            findings.append("Slightly delayed pupil response")
        else:
            findings.append("Normal pupil response time")
    
    # Check constriction (normal: 20-80%)
    if latest_test.pupil_constriction_percent:
        constriction = latest_test.pupil_constriction_percent
        if constriction < 20:
            score -= 20
            findings.append("Weak pupil constriction")
        elif constriction > 80:
            score -= 15
            findings.append("Excessive pupil constriction")
        else:
            findings.append("Normal pupil constriction")
    
    # Check nystagmus
    if latest_test.nystagmus_detected:
        severity_penalties = {'mild': 15, 'moderate': 25, 'severe': 40}
        penalty = severity_penalties.get(latest_test.nystagmus_severity, 20)
        score -= penalty
        findings.append(f"{latest_test.nystagmus_severity.title()} {latest_test.nystagmus_type} nystagmus detected")
    else:
        findings.append("No nystagmus detected")
    
    return max(score, 0), "; ".join(findings)

def analyze_trends(tests_by_type):
    """Analyze trends across multiple tests over time"""
    trends = {}
    
    # Visual acuity trend
    if 'visual_acuity' in tests_by_type and len(tests_by_type['visual_acuity']) > 1:
        recent = tests_by_type['visual_acuity'][0]
        older = tests_by_type['visual_acuity'][-1]
        
        # Compare Snellen results
        try:
            if recent.snellen_result and older.snellen_result:
                recent_score = float(recent.snellen_result.split('/')[0]) / float(recent.snellen_result.split('/')[1])
                older_score = float(older.snellen_result.split('/')[0]) / float(older.snellen_result.split('/')[1])
                
                if recent_score > older_score * 1.1:
                    trends['visual_acuity'] = 'improving'
                elif recent_score < older_score * 0.9:
                    trends['visual_acuity'] = 'declining'
                else:
                    trends['visual_acuity'] = 'stable'
        except:
            trends['visual_acuity'] = 'insufficient_data'
    
    # Blink fatigue trend
    if 'blink_fatigue' in tests_by_type and len(tests_by_type['blink_fatigue']) > 1:
        fatigue_detected_recent = sum(1 for t in tests_by_type['blink_fatigue'][:3] if t.fatigue_detected)
        fatigue_detected_older = sum(1 for t in tests_by_type['blink_fatigue'][-3:] if t.fatigue_detected)
        
        if fatigue_detected_recent > fatigue_detected_older:
            trends['blink_fatigue'] = 'worsening'
        elif fatigue_detected_recent < fatigue_detected_older:
            trends['blink_fatigue'] = 'improving'
        else:
            trends['blink_fatigue'] = 'stable'
    
    return trends

def generate_ai_summary(scores, findings, trends):
    """Generate natural language summary of eye health"""
    summary_parts = []
    
    # Overall health assessment
    avg_score = sum(s for s in scores.values() if s is not None) / len([s for s in scores.values() if s is not None])
    
    if avg_score >= 90:
        summary_parts.append("Your eye health is excellent with all tests showing optimal results.")
    elif avg_score >= 75:
        summary_parts.append("Your eye health is generally good with some minor areas requiring attention.")
    elif avg_score >= 60:
        summary_parts.append("Your eye health shows moderate concerns that should be addressed.")
    else:
        summary_parts.append("Your eye health requires immediate attention and professional consultation.")
    
    # Specific concerns
    concerns = []
    if scores.get('visual_acuity') and scores['visual_acuity'] < 80:
        concerns.append("visual acuity impairment")
    if scores.get('colour_vision') and scores['colour_vision'] < 90:
        concerns.append("colour vision deficiency")
    if scores.get('blink_fatigue') and scores['blink_fatigue'] < 70:
        concerns.append("eye fatigue and blink abnormalities")
    if scores.get('pupil_reflex') and scores['pupil_reflex'] < 75:
        concerns.append("pupil reflex irregularities")
    
    if concerns:
        summary_parts.append(f"Key concerns include: {', '.join(concerns)}.")
    
    # Trends
    if trends:
        improving = [k for k, v in trends.items() if v == 'improving']
        declining = [k for k, v in trends.items() if v == 'declining']
        
        if improving:
            summary_parts.append(f"Positive trends observed in {', '.join(improving).replace('_', ' ')}.")
        if declining:
            summary_parts.append(f"Declining trends in {', '.join(declining).replace('_', ' ')} require monitoring.")
    
    return " ".join(summary_parts)

def generate_recommendations(scores, findings, user):
    """Generate personalized recommendations based on test results"""
    recommendations = []
    
    # Visual acuity recommendations
    if scores.get('visual_acuity'):
        if scores['visual_acuity'] < 80:
            recommendations.append("Schedule a comprehensive eye exam with an optometrist for vision correction options")
            recommendations.append("Consider prescription eyeglasses or contact lenses if not already using them")
        elif scores['visual_acuity'] < 95:
            recommendations.append("Monitor vision changes and schedule routine eye exam within 6 months")
    
    # Colour vision recommendations
    if scores.get('colour_vision') and scores['colour_vision'] < 90:
        recommendations.append("Consider using colour-corrective lenses or apps for daily activities")
        recommendations.append("Inform relevant parties (employer, school) about colour vision deficiency if it affects work/studies")
    
    # Blink fatigue recommendations
    if scores.get('blink_fatigue') and scores['blink_fatigue'] < 70:
        recommendations.append("Take regular breaks from screen use (20-20-20 rule: every 20 minutes, look 20 feet away for 20 seconds)")
        recommendations.append("Use artificial tears to combat dry eye symptoms")
        recommendations.append("Adjust screen brightness and ensure proper ergonomics")
        recommendations.append("Consider blue light filtering glasses for extended screen use")
    
    # Pupil reflex recommendations
    if scores.get('pupil_reflex') and scores['pupil_reflex'] < 75:
        recommendations.append("Consult a neurologist or ophthalmologist for detailed pupil reflex evaluation")
        if 'nystagmus' in findings.get('pupil_reflex', '').lower():
            recommendations.append("Vestibular function testing may be beneficial to assess balance and coordination")
    
    # General recommendations
    recommendations.append("Maintain a healthy diet rich in vitamins A, C, and E for optimal eye health")
    recommendations.append("Protect eyes from UV radiation with quality sunglasses outdoors")
    recommendations.append("Stay hydrated to prevent dry eye symptoms")
    
    # Age-specific recommendations
    if user.age:
        if user.age >= 40:
            recommendations.append("Annual eye exams recommended for early detection of age-related conditions (cataracts, glaucoma, macular degeneration)")
        if user.age >= 60:
            recommendations.append("Increase monitoring frequency to bi-annual eye exams")
    
    return recommendations

@ai_report_ns.route('/generate')
class GenerateReport(Resource):
    """Generate comprehensive AI eye health report"""
    
    @ai_report_ns.doc(security='Bearer')
    @ai_report_ns.expect(generate_report_model)
    @token_required
    def post(self, current_user):
        """Generate a new AI-powered eye health report"""
        try:
            data = request.get_json() or {}
            
            time_range_days = data.get('time_range_days', 30)
            cutoff_date = datetime.utcnow() - timedelta(days=time_range_days)
            
            # Gather all test results
            tests_by_type = {
                'visual_acuity': VisualAcuityTest.query.filter(
                    VisualAcuityTest.user_id == current_user.id,
                    VisualAcuityTest.test_date >= cutoff_date
                ).order_by(desc(VisualAcuityTest.test_date)).all(),
                
                'colour_vision': ColourVisionTest.query.filter(
                    ColourVisionTest.user_id == current_user.id,
                    ColourVisionTest.test_date >= cutoff_date
                ).order_by(desc(ColourVisionTest.test_date)).all(),
                
                'blink_fatigue': BlinkFatigueTest.query.filter(
                    BlinkFatigueTest.user_id == current_user.id,
                    BlinkFatigueTest.test_date >= cutoff_date
                ).order_by(desc(BlinkFatigueTest.test_date)).all(),
                
                'pupil_reflex': PupilReflexTest.query.filter(
                    PupilReflexTest.user_id == current_user.id,
                    PupilReflexTest.test_date >= cutoff_date
                ).order_by(desc(PupilReflexTest.test_date)).all()
            }
            
            # Calculate scores for each test type
            scores = {}
            findings = {}
            
            va_score, va_finding = calculate_visual_acuity_score(tests_by_type['visual_acuity'])
            if va_score is not None:
                scores['visual_acuity'] = va_score
                findings['visual_acuity'] = va_finding
            
            cv_score, cv_finding = calculate_colour_vision_score(tests_by_type['colour_vision'])
            if cv_score is not None:
                scores['colour_vision'] = cv_score
                findings['colour_vision'] = cv_finding
            
            bf_score, bf_finding = calculate_blink_fatigue_score(tests_by_type['blink_fatigue'])
            if bf_score is not None:
                scores['blink_fatigue'] = bf_score
                findings['blink_fatigue'] = bf_finding
            
            pr_score, pr_finding = calculate_pupil_reflex_score(tests_by_type['pupil_reflex'])
            if pr_score is not None:
                scores['pupil_reflex'] = pr_score
                findings['pupil_reflex'] = pr_finding
            
            # Calculate overall score
            if scores:
                overall_score = sum(scores.values()) / len(scores)
            else:
                return {'message': 'No tests available to generate report. Please complete at least one test.'}, 400
            
            # Analyze trends
            trends = analyze_trends(tests_by_type)
            
            # Generate AI summary
            summary = generate_ai_summary(scores, findings, trends)
            
            # Generate recommendations
            recommendations = generate_recommendations(scores, findings, current_user)
            
            # Create report response
            report = {
                'report_id': f"R-{current_user.id}-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
                'user_id': current_user.id,
                'generation_date': datetime.utcnow().isoformat(),
                'report_type': data.get('report_type', 'comprehensive'),
                'time_range_days': time_range_days,
                'overall_score': round(overall_score, 2),
                'summary': summary,
                'findings': findings,
                'scores': scores,
                'recommendations': recommendations,
                'trends': trends,
                'test_counts': {
                    'visual_acuity': len(tests_by_type['visual_acuity']),
                    'colour_vision': len(tests_by_type['colour_vision']),
                    'blink_fatigue': len(tests_by_type['blink_fatigue']),
                    'pupil_reflex': len(tests_by_type['pupil_reflex'])
                }
            }
            
            return {
                'message': 'Report generated successfully',
                'report': report
            }, 200
        
        except Exception as e:
            return {'message': f'Failed to generate report: {str(e)}'}, 500

@ai_report_ns.route('/latest')
class GetLatestReport(Resource):
    """Get user's most recent report"""
    
    @ai_report_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Retrieve the most recent eye health report"""
        # For now, generate on-demand since we're not storing reports in database yet
        return GenerateReport().post(current_user)

@ai_report_ns.route('/insights')
class GetInsights(Resource):
    """Get quick health insights without full report"""
    
    @ai_report_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get quick eye health insights"""
        try:
            # Get most recent test of each type
            latest_visual = VisualAcuityTest.query.filter_by(user_id=current_user.id).order_by(desc(VisualAcuityTest.test_date)).first()
            latest_colour = ColourVisionTest.query.filter_by(user_id=current_user.id).order_by(desc(ColourVisionTest.test_date)).first()
            latest_blink = BlinkFatigueTest.query.filter_by(user_id=current_user.id).order_by(desc(BlinkFatigueTest.test_date)).first()
            latest_pupil = PupilReflexTest.query.filter_by(user_id=current_user.id).order_by(desc(PupilReflexTest.test_date)).first()
            
            insights = []
            
            if latest_visual:
                insights.append({
                    'type': 'visual_acuity',
                    'message': f"Last visual acuity test: {latest_visual.snellen_result or 'N/A'}",
                    'date': latest_visual.test_date.isoformat() if latest_visual.test_date else None
                })
            
            if latest_colour and latest_colour.deficiency_detected:
                insights.append({
                    'type': 'colour_vision',
                    'message': f"{latest_colour.deficiency_type.replace('_', ' ').title()} deficiency detected",
                    'severity': latest_colour.deficiency_severity,
                    'date': latest_colour.test_date.isoformat() if latest_colour.test_date else None
                })
            
            if latest_blink and latest_blink.fatigue_detected:
                insights.append({
                    'type': 'blink_fatigue',
                    'message': f"{latest_blink.fatigue_level.title()} eye fatigue detected",
                    'date': latest_blink.test_date.isoformat() if latest_blink.test_date else None
                })
            
            if latest_pupil and latest_pupil.nystagmus_detected:
                insights.append({
                    'type': 'pupil_reflex',
                    'message': f"{latest_pupil.nystagmus_severity.title()} nystagmus detected",
                    'date': latest_pupil.test_date.isoformat() if latest_pupil.test_date else None
                })
            
            return {
                'total_insights': len(insights),
                'insights': insights,
                'last_updated': datetime.utcnow().isoformat()
            }, 200
        
        except Exception as e:
            return {'message': f'Failed to get insights: {str(e)}'}, 500
