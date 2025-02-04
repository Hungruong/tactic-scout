from typing import Dict, List, Optional
import os
import google.generativeai as genai
from .stats_fetcher import PlayerStatsFetcher
import logging

class GeminiTacticalAnalyzer:
    def __init__(self, api_key: str = None):
        if api_key is None:
            api_key = os.getenv('GEMINI_API_KEY')
            if api_key is None:
                raise ValueError("No Gemini API key provided. Set GEMINI_API_KEY environment variable.")
        
        try:
            genai.configure(api_key=api_key)
            self.model = genai.GenerativeModel('gemini-pro')
            self.stats_fetcher = PlayerStatsFetcher()
            logging.info("Gemini analyzer initialized successfully")
        except Exception as e:
            logging.error(f"Failed to initialize Gemini analyzer: {str(e)}")
            raise

    def generate_tactical_analysis(self, predictions: Dict, game_state: Dict, context: Dict) -> str:
        try:
            # Extract situation details
            inning = context['game_situation']['inning']
            outs = context['game_situation']['outs']
            score_diff = context['game_situation'].get('score_diff', 0)
            runners_detail = self._get_runners_detail(context['runner_situation'])
            
            # Get player info
            matchup = game_state.get('matchup', {})
            batter_id = matchup.get('batter', {}).get('id')
            pitcher_id = matchup.get('pitcher', {}).get('id')
            batter_stats = self.stats_fetcher.get_batter_stats(batter_id) if batter_id else {}
            pitcher_stats = self.stats_fetcher.get_pitcher_stats(pitcher_id) if pitcher_id else {}
            batter_name = matchup.get('batter', {}).get('fullName', 'Unknown Batter')
            pitcher_name = matchup.get('pitcher', {}).get('fullName', 'Unknown Pitcher')

            # Format tactics
            ordered_tactics = sorted(predictions.get('top_tactics', {}).items(), key=lambda x: x[1], reverse=True)[:3]
            tactics_str = "\n".join([f"- **{tactic}** ({prob:.2f}%)" for tactic, prob in ordered_tactics])
            
            prompt = f"""
            Analyze this baseball situation. Output must follow exactly this format:

            Top Predicted Tactics:
            {tactics_str}

            Analysis:
            [One detailed paragraph explaining why {ordered_tactics[0][0]} is predicted at {ordered_tactics[0][1]:.2f}%. Include:
            - Game context: {inning} inning, {outs} out(s), {self._format_score_situation(score_diff)}, {runners_detail}
            - How {batter_name}'s stats (AVG {batter_stats.get('avg', 0):.3f}, {batter_stats.get('home_runs', 0)} HR) influence this
            - How {pitcher_name}'s performance (ERA {pitcher_stats.get('era', 0):.2f}, K/9 {pitcher_stats.get('k_per_9', 0):.1f}) affects probability
            - Why this tactic is most appropriate for this situation]
            
            Do not add any sections or change the format above.
            """

            response = self.model.generate_content(prompt)
            return self._format_response(response.text)
            
        except Exception as e:
            logging.error(f"Error generating analysis: {str(e)}")
            return f"Error generating analysis: {str(e)}"

    def _get_runners_detail(self, runner_situation: Dict) -> str:
        runners = []
        if runner_situation.get('runner_on_first'):
            runners.append("1st")
        if runner_situation.get('runner_on_second'):
            runners.append("2nd")
        if runner_situation.get('runner_on_third'):
            runners.append("3rd")
        return "Runners on " + " and ".join(runners) if runners else "No runners on base"

    def _format_score_situation(self, score_diff: int) -> str:
        if score_diff > 0:
            return f"Leading by {score_diff}"
        elif score_diff < 0:
            return f"Trailing by {abs(score_diff)}"
        return "Tied game"

    def _format_response(self, response: str) -> str:
        try:
            # Clean and split response
            sections = response.strip().replace('****', '').split('\n\n')
            if len(sections) < 2:
                return "Error: Incomplete analysis"
            
            # Extract and format sections
            tactics = sections[0].replace('Top Predicted Tactics:', '').strip()
            analysis = sections[1].replace('Analysis:', '').strip()
            
            # Return formatted result
            return f"**Top Predicted Tactics:**\n{tactics}\n\n**Analysis:**\n{analysis}"
            
        except Exception as e:
            logging.error(f"Error formatting response: {str(e)}")
            return "Error formatting analysis"