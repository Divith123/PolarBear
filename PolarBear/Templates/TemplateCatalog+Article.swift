//
//  TemplateCatalog+Article.swift
//  PolarBear
//

extension TemplateCatalog {
    static let blankSource = #"""
\documentclass{article}

\begin{document}

\end{document}
"""#

    static let articleSource = #"""
\documentclass[11pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage{amsmath}

\title{A Title for Your Paper}
\author{Your Name}
\date{\today}

\begin{document}
\maketitle

\begin{abstract}
A short summary of what this paper does, in two or three sentences.
\end{abstract}

\section{Introduction}
Start writing here. Press \textbf{Command-R} to compile; the preview also updates by itself while you type.

\section{Method}
Equations are typeset in math mode, for example
\begin{equation}
  e^{i\pi} + 1 = 0 .
\end{equation}

\subsection{Results}
\begin{tabular}{lrr}
  \hline
  Case & Value & Error \\
  \hline
  A & 1.00 & 0.02 \\
  B & 2.50 & 0.10 \\
  \hline
\end{tabular}

\section{Conclusion}
What the reader should remember.

\end{document}
"""#
}
